classdef recipe < handle
    % recipe
    %
    % The recipe class handles the settings that define an acquisition.
    %


    properties (SetObservable, AbortSet)
        %Define legal default values for all parameters. This way it will be possible
        %to use the recipe to do *something*, even if that something isn't especially 
        %useful. 

        sample=struct('ID', '', ...           % String defining the sample name
                     'objectiveName', '16x')     % String defining the objective name

        mosaic=struct('sectionStartNum', 1, ...    % Integer defining the number of the first section (used for file name creation)
                    'numSections', 1, ...          % Integer defining how many sections to take
                    'numOpticalPlanes', 2, ...     % Integer defining the number of optical planes (layers) to image
                    'overlapProportion', 0.05, ... % Value from 0 to 0.5 defining how much overlap there should be between adjacent tiles
                    'sampleSize', struct('X',1, 'Y',1), ...  % The size of the sample in mm
                    'scanmode', 'tile')            % String defining how the data are to be acquired. (e.g. "tile": tile acquisition). 

        FrontLeft=struct('X',0, 'Y',0)           % Front/left position of the tile array
    end

    properties (SetAccess=protected)
        %These properties are set by the recipe class. see: 
        %  - recipe.recordScannerSettings
        %  - recipe.tilePattern
        NumTiles=struct('X',0, 'Y',0)
        Tile=struct('nRows',0, 'nColumns',0)
        TileStepSize=struct('X',0, 'Y',0);     %How far the stage moves in mm between tiles to four decimal places. 
        VoxelSize=struct('X',0,'Y', 0,'Z',0);
        ScannerSettings=struct('type','') %TODO - SIBT should return. It should contain the scanner name. 

        %These properties are populated by structures that can be set by the user only by editing 
        %SETTINGS/systemSettings.yml
        SYSTEM
    end %close protected properties

    properties (Hidden)
        Acquisition=struct('acqStartTime','')
        verbose=0;
        fname
        parent
    end


    properties (SetAccess=protected,Hidden)
        listeners={}
    end


    %The following properties are for tasks such as GUI updating and broadasting the state of the 
    %recipe to other components
    properties (SetObservable, AbortSet, Hidden)
        acquisitionPossible=false %set to true if all settings indicate an acquisition is likely possible (e.g. front/left is set and so forth)
    end



    methods
        function obj=recipe(recipeFname) %Constructor
            %Optionally return the error/warning message that might have been produced during reading of the recipe

            %Import the parameter (recipe) file
            msg='';
            if nargin<1 || isempty(recipeFname)
                [params,recipeFname] = tilerUtils.settings.readDefaultRecipe;
            elseif nargin>0 && ~isempty(recipeFname)
                [params,msg]=tilerUtils.settings.readRecipe(recipeFname);
                if isempty(params)
                    msg=sprintf(['*** Reading of recipe %s by tilerUtils.settings.readRecipe seems to have failed.\n', ...
                        '*** Using default values instead.\n'], recipeFname);
                    [params,recipeFname] = tilerUtils.settings.readDefaultRecipe;
                end
                if ~isempty(msg)
                    %If we're here, there was an warning and we can carry on with the the desired recipe file
                    fprintf(msg) %Otherwise just report the error
                end
            end

            %Add these recipe parameters as properties
            obj.sample = params.sample;
            obj.mosaic = params.mosaic;

            %Add the system settings from the settings file. 
            sysSettings = tilerUtils.settings.readSystemSettings;

            if isempty(sysSettings)
                error('Reading of system settings by tilerUtils.settings.readSystemSettings seems to have failed')
            end



            obj.fname=recipeFname;


            %Put listeners on some of the properties and use these to update the acquisitionPossible porperty
            listeners{1}=addlistener(obj,'sample', 'PostSet', @obj.checkIfAcquisitionIsPossible);
            listeners{2}=addlistener(obj,'mosaic', 'PostSet', @obj.checkIfAcquisitionIsPossible);
            listeners{4}=addlistener(obj,'FrontLeft', 'PostSet', @obj.checkIfAcquisitionIsPossible);

        end %Constructor


        function delete(obj)
            for ii=1:length(obj.listeners)
                delete(obj.listeners{ii})
                obj.listeners=[];
            end
        end %destructor


        % - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - 
        % Convenience methods
        function success=recordScannerSettings(obj)
            if isempty(obj.parent)
                success=false;
                fprintf('ERROR: recipe class has nothing bound to property "parent". Can not access BT\n')
                return
            end
            if ~isempty(obj.parent.scanner)
                obj.ScannerSettings = obj.parent.scanner.returnScanSettings;

                obj.VoxelSize.X = obj.ScannerSettings.micronsPerPixel_cols;
                obj.VoxelSize.Y = obj.ScannerSettings.micronsPerPixel_rows;
                obj.VoxelSize.Z = obj.ScannerSettings.micronsBetweenOpticalPlanes;
                obj.Tile.nRows  = obj.ScannerSettings.linesPerFrame;
                obj.Tile.nColumns = obj.ScannerSettings.pixelsPerLine;
                success=true;
            else
                success=false;
            end
        end

        function numTiles = numTilesInOpticalSection(obj)
            %Return the number of tiles to be imaged in one plane
            numTiles = obj.NumTiles.X * obj.NumTiles.Y ;
        end

        function numTiles = numTilesInPhysicalSection(obj)
            %Return the number of tiles to be imaged in one physical section
            numTiles = obj.NumTiles.X * obj.NumTiles.Y * obj.mosaic.numOpticalPlanes ;
        end


        % - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - 
        % Methods for setting up the imaging scene
        function setCurrentPositionAsFrontLeft(obj)
            %TODO: add error checks
            if isempty(obj.parent)
                success=false;
                fprintf('ERROR: recipe class has nothing bound to property "parent". Can not access BT\n')
                return
            end
            thisOBJ=obj.parent;
            [x,y]=thisOBJ.getXYpos;
            obj.FrontLeft.X = x;
            obj.FrontLeft.Y = y;
        end


    end %methods




    % - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - 
    %Getters and setters
    methods

        % Setter for the recipe.sample structure. 
        % This is used to ensure that the values entered by the user are valid
        function obj = set.sample(obj,val)
            oldVal = obj.sample; % store the previous values
            theseFields = fields(oldVal);

            %If we're acquiring data, don't change anything
            if ~isempty(obj.parent)
                return
            end

            for fn = theseFields(:)' % loop through fields to check what has changed
                if ~isstruct(val)
                    %The user is trying to assign something directly to sample
                    return
                end

                field2check = fn{1};
                fieldValue=val.(field2check);
                if isfield(val,field2check)
                    switch field2check
                        case 'ID'
                            if ischar(fieldValue)
                                % Generate a base file name for the sample, replacing or removing unusual characters
                                % This is to ensure the user can't make up silly names that cause problems down the line.
                                fieldValue = regexprep(fieldValue, ' ', '_');
                                fieldValue = regexprep(fieldValue, '[^0-9a-z_A-Z]', '');
                                if length(fieldValue)>0
                                    if regexp(fieldValue(1),'\d')
                                        %Do not allow sample name to start with a number
                                        fieldValue = ['sample_',fieldValue];
                                    elseif regexpi(fieldValue(1),'[^a-z]')
                                        %Do not allow the sample to start with something that isn't a letter
                                        fieldValue = ['sample_',fieldValue(2:end)];
                                    end
                                end
                            end

                            %If the sample name is not a string or empty then we just make one up
                            if ~ischar(fieldValue) || length(fieldValue)==0
                                fieldValue=['sample_',datestr(now,'yy-mm-dd_HHMMSS')];
                                fprintf('Setting sample name to: %s\n',fieldValue)
                            end
                            obj.sample.(field2check) = fieldValue;

                          case 'objectiveName'
                            if ischar(fieldValue)
                                obj.sample.(field2check) = fieldValue;
                            else
                                fprintf('ERROR: sample.objectiveName must be a string!\n')
                            end
                    end %switch
               end %if isfield
            end
        end % set.sample



        % Setter for the recipe.mosaic structure. 
        % This is used to ensure that the values entered by the user are valid
        function obj = set.mosaic(obj,val)
            oldVal = obj.mosaic; % store the previous values
            theseFields = fields(oldVal);

            %If we're acquiring data, don't change anything
            if ~isempty(obj.parent)
                return
            end


            for fn = theseFields(:)' % loop through fields to check what has changed
                field2check = fn{1};
                if ~isstruct(val)
                    %The user is trying to assign something directly to mosaic
                    return
                end
                fieldValue=val.(field2check);
                if isfield(val,field2check)
                    switch field2check

                        case 'scanmode'
                            if ischar(fieldValue)
                                %Pass - the value will be assigned at the end of the method
                            else
                                fprintf('ERROR: mosaic.scanmode must be a string!\n')
                                fieldValue=[]; %Will stop. the assignment from happening
                            end
                            if ~strcmp(fieldValue,'tile')
                                fprintf('ERROR: mosaic.scanmode can currently only be set to "tile"\n')
                                fieldValue=[]; %As above, will stop the assignment.
                            end

                        case 'sectionStartNum'
                            fieldValue = obj.checkInteger(fieldValue);
                        case 'numSections'
                            fieldValue = obj.checkInteger(fieldValue);
                        case 'numOpticalPlanes'
                            fieldValue = obj.checkInteger(fieldValue);
                        case 'overlapProportion'
                            fieldValue = obj.checkFloat(fieldValue,0,0.5); %Overlap allowed up to 50%
                        case 'sampleSize'
                            if ~isstruct(fieldValue)
                                fieldValue=[];
                            else 
                                %Do not allow the sample size to be smaller than the tile size
                                if obj.TileStepSize.X==0
                                    minSampleSizeX=0.05;
                                else
                                    minSampleSizeX=obj.TileStepSize.X;
                                end

                                if obj.TileStepSize.Y==0
                                    minSampleSizeY=0.05;
                                else
                                    minSampleSizeY=obj.TileStepSize.Y;
                                end

                                fieldValue.X = obj.checkFloat(fieldValue.X, minSampleSizeX, 20);
                                fieldValue.Y = obj.checkFloat(fieldValue.Y, minSampleSizeY, 20);
                                if isempty(fieldValue.X) || isempty(fieldValue.Y)
                                    fieldValue=[];
                                end
                            end
                        otherwise
                            fprintf('ERROR in recipe class: unknown field: %s\n',field2check)
                            fieldValue=[];
                    end %switch

                    %Values that aren't empty are deemed valid and assigned
                    if ~isempty(fieldValue)
                        obj.mosaic.(field2check) = fieldValue;
                    end

               end %if isfield
            end
        end % set.mosaic





    end %methods: getters/setters

    methods (Hidden)
        %Convenience methods that aren't methods
        function value=checkInteger(~,value)
            %Confirm that an input is a positive integer
            %Coerce floats to ints. 
            %Returns empty if the input is not valid. 
            %Empty values aren't assigned to a property by the setters
            if ~isnumeric(value) || ~isscalar(value)
                value=[];
                return
            end

            if value<=0
                value=[];
                return
            end

            value = ceil(value);
        end %checkInteger

        function value=checkFloat(~,value,minVal,maxVal)
            %Confirm that an input is a positive float no smaller than minVal and 
            %no larger than maxVal. Returns empty if the input is not valid. 
            %Empty values aren't assigned to a property by the setters
            if nargin<3
                maxVal=inf;
            end
            if ~isnumeric(value) || ~isscalar(value)
                value=[];
                return
            end

            if value<minVal
                value=minVal;
                return
            end
            if value>maxVal
                value=maxVal;
                return
            end
        end %checkFloat

        function checkIfAcquisitionIsPossible(obj,~,~)
            %Check if it will be possible to acquire data based on the current recipe settings
            if isempty(obj.FrontLeft.X) || isempty(obj.FrontLeft.Y) || ...
                isempty(obj.mosaic.sampleSize.X) || isempty(obj.mosaic.sampleSize.Y)
                obj.acquisitionPossible=false;
                return
            end

            if isempty(obj.sample.ID)
                obj.acquisitionPossible=false;
                return
            end

            obj.acquisitionPossible=true;
        end %checkIfAcquisitionIsPossible


    end %Hidden methods

end