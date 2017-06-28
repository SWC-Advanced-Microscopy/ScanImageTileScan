classdef SIBT < scanner
%% SIBT
% This is a wrapper class that inherits the abstract class, scanner. 
% The SIBT concrete class as a glue or bridge to ScanImage. This class 
% implements all the methods needed to trigger image acquisition, set the 
% power at the sample, and save images, etc. 
%

    properties (Hidden)
        defaultShutterIDs %The default shutter IDs used by the scanner
        maxStripe=1; %Number of channel window updates per second
        listeners={}
        
    end


    methods

        %constructor
        function obj=SIBT(API)
            if nargin<1
                API=[];
            end
            obj.connect(API);

        end %constructor


        %destructor
        function delete(obj)
            cellfun(@delete,obj.listeners)
            obj.hC=[];
        end %destructor


        % - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - 
        function success = connect(obj,API)
            %TODO: why the hell isn't this in the constructor?
            success=false;

            if nargin<2 || isempty(API)
                scanimageObjectName='hSI';
                W = evalin('base','whos');
                SIexists = ismember(scanimageObjectName,{W.name});
                if ~SIexists
                    disp('ScanImage not started. Can not connect to scanner.')
                    return
                end

                API = evalin('base',scanimageObjectName); % get hSI from the base workspace
            end

            if ~isa(API,'scanimage.SI')
                error('hSI is not a ScanImage object.')
                return
            end

            obj.hC=API;

            fprintf('\n\nStarting SIBT interface for ScanImage\n')
            %Log default state of settings so we return to these when disarming
            obj.defaultShutterIDs = obj.hC.hScan2D.mdfData.shutterIDs;

            %Set up a user frame-acquired callback.
            U.EventName='acqModeDone';
            U.UserFcnName='SI_userFunction';
            U.Arguments={};
            U.Enable=0;

            obj.hC.hUserFunctions.userFunctionsCfg=U;

            switch obj.scannerType
                case 'resonant'
                    %To make it possible to enable the external trigger. PFI0 is reserved for resonant scanning
                    obj.hC.hScan2D.trigAcqInTerm='PFI1';
                case 'linear'
                    obj.hC.hScan2D.trigAcqInTerm='PFI0';
            end

            %Set up listeners on ScanImage to relay changing properties
            obj.listeners{end+1}=addlistener(obj.hC.hStackManager, 'stackSlicesDone', 'PostSet', @obj.updateCurrentZplane);

            %Set up a listener on the sample rate to ensure it's a safe value
            obj.listeners{end+1} = addlistener(obj.hC, 'active', 'PostSet', @obj.isAcquiring);

            obj.enforceImportantSettings
            %Set listeners on properties we don't want the user to change. Hitting any of these
            %will call a single method that resets all of the properties to the values we desire. 
            obj.listeners{end+1} = addlistener(obj.hC.hRoiManager, 'forceSquarePixels', 'PostSet', @obj.enforceImportantSettings);
            obj.listeners{end+1} = addlistener(obj.hC.hScan2D, 'bidirectional', 'PostSet', @obj.enforceImportantSettings);

            obj.updateCurrentZplane


            %We now set some values to optimal settings for proceeding, but these are not critical.
            fprintf(' - Setting fast z waveform type to "step"\n')
            obj.hC.hFastZ.waveformType='step'; %Enforced anyway when arming the scanner

            %Supply a reasonable default for the illumination with depth adjustment and report to the command line 
            Lz=180;
            fprintf(' - Setting up power/depth correction using Lz=%d.\n   You may change this value in "POWER CONTROLS". (Smaller numbers will increase the power more with depth.)\n',Lz)
            obj.hC.hBeams.pzAdjust=true;
            obj.hC.hBeams.lengthConstants=Lz;

            success=true;
        end %connect


        function ready = isReady(obj)
            if isempty(obj.hC)
                ready=false;
                return
            end
            ready=strcmpi(obj.hC.acqState,'idle');
        end %isReady


        function success = armScanner(obj)
            %Arm scanner and tell it to acquire a fixed number of frames (as defined below)
            success=false;
            if isempty(obj.parent) || ~obj.parent.isRecipeConnected
                disp('SIBT is not attached to a BT object with a recipe')
                return
            end

            %TODO: add checks to confirm that all of the following happened
            obj.toggleUserFunction('SI_userFunction',true);

            if obj.hC.hDisplay.displayRollingAverageFactor>1
                fprintf('Setting display rolling average to 1\n')
                obj.hC.hDisplay.displayRollingAverageFactor=1;
            end

            %Set up for Z-stacks if we'll be doing those
            thisRecipe = obj.parent.recipe;
            if thisRecipe.mosaic.numOpticalPlanes>1
                fprintf('Setting up z-scanning with "step" waveform\n')
                obj.hC.hFastZ.waveformType = 'step'; %Always
                obj.hC.hFastZ.numVolumes=1; %Always
                obj.hC.hFastZ.enable=1;

                obj.hC.hStackManager.framesPerSlice = 1; %Always (number of frames per grab per layer)
                obj.hC.hStackManager.numSlices = thisRecipe.mosaic.numOpticalPlanes;
                obj.hC.hStackManager.stackZStepSize = 100; %HARD-CODED IN MICRONS -- WE ALWAYS USE THIS THICKNESS
                obj.hC.hStackManager.stackReturnHome = 1;


                fprintf('Setting PIFOC settling time to %0.3f ms\n', 15);
                obj.hC.hFastZ.flybackTime = 15/1E3;

                if isfield(obj.hC.hScan2D.mdfData,'stripingMaxRate') &&  obj.hC.hScan2D.mdfData.stripingMaxRate>obj.maxStripe
                    %The number of channel window updates per second
                    fprintf('Restricting display stripe rate to %d Hz. This can speed up acquisition.\n',obj.maxStripe)
                    obj.hC.hScan2D.mdfData.stripingMaxRate=obj.maxStripe;
                end

                if strcmp(obj.hC.hDisplay.volumeDisplayStyle,'3D')
                    fprintf('Setting volume display style from 3D to Tiled\n')
                    obj.hC.hDisplay.volumeDisplayStyle='Tiled';
                end

            else
                %Ensure we disable z-scanning
                obj.hC.hStackManager.numSlices = 1;
                obj.hC.hStackManager.stackZStepSize = 0;
            end

            %If any of these fail, we leave the function gracefully
            try
                obj.hC.acqsPerLoop=thisRecipe.numTilesInOpticalSection;% This is the number of x/y positions that need to be visited
                obj.hC.extTrigEnable=1;
                %Put it into acquisition mode but it won't proceed because it's waiting for a trigger
                obj.hC.startLoop;
            catch ME1
                rethrow(ME1)
                return
            end

            success=true;

            obj.hC.hScan2D.mdfData.shutterIDs=[]; %Disable shutters

        end %armScanner


        function success = disarmScanner(obj)
            %TODO: how to abort a loop?
            %TODO: use the listeners to run this method if the user presses "Abort"
            if obj.hC.active
                disp('Scanner still in acquisition mode. Can not disarm.')
                success=false;
                return
            end

            %Disable z sectioning
            obj.hC.hFastZ.enable=0;
            hSI.hStackManager.numSlices = 1;

            obj.hC.extTrigEnable=0;  
            obj.hC.hScan2D.mdfData.shutterIDs=obj.defaultShutterIDs; %re-enable shutters
            obj.toggleUserFunction('SI_userFunction',false);
            obj.hC.hChannels.loggingEnable=false;

            success=true;
        end %disarmScanner


        function abortScanning(obj)
            obj.hC.hCycleManager.abort;
        end


        function acquiring = isAcquiring(obj,~,~)
            %Returns true if a focus, loop, or grab is in progress even if the system is not
            %currently acquiring a frame
            acquiring=obj.hC.active;
            obj.isScannerAcquiring=acquiring;
        end %isAcquiring


        %---------------------------------------------------------------
        % The following methods are not part of scanner. Maybe they should be, we need to decide
        function framePeriod = getFramePeriod(obj) %TODO: this isn't in the abstract class.
            %return the frame period (how long it takes to acquire a frame) in seconds
            framePeriod = obj.hC.hRoiManager.scanFramePeriod;
        end %getFramePeriod


        function scanSettings = returnScanSettings(obj)
            scanSettings.pixelsPerLine = obj.hC.hRoiManager.pixelsPerLine;
            scanSettings.linesPerFrame = obj.hC.hRoiManager.linesPerFrame;
            scanSettings.micronsBetweenOpticalPlanes = obj.hC.hStackManager.stackZStepSize;
            scanSettings.zoomFactor = obj.hC.hRoiManager.scanZoomFactor;

            scanSettings.scannerMechanicalAnglePP_fast_axis = round(range(obj.hC.hRoiManager.imagingFovDeg(:,1)),3);
            scanSettings.scannerMechanicalAnglePP_slowAxis =  round(range(obj.hC.hRoiManager.imagingFovDeg(:,2)),3);

            scanSettings.FOV_alongColsinMicrons = round(range(obj.hC.hRoiManager.imagingFovUm(:,1)),3);
            scanSettings.FOV_alongRowsinMicrons = round(range(obj.hC.hRoiManager.imagingFovUm(:,2)),3);
           
            scanSettings.micronsPerPixel_cols = round(scanSettings.FOV_alongColsinMicrons/scanSettings.pixelsPerLine,3);
            scanSettings.micronsPerPixel_rows = round(scanSettings.FOV_alongRowsinMicrons/scanSettings.linesPerFrame,3);
            
            scanSettings.framePeriodInSeconds = round(1/obj.hC.hRoiManager.scanFrameRate,3);
            scanSettings.pixelTimeInMicroSeconds = round(obj.hC.hScan2D.scanPixelTimeMean * 1E6,4);
            scanSettings.linePeriodInMicroseconds = round(obj.hC.hRoiManager.linePeriod * 1E6,4);
            scanSettings.bidirectionalScan = obj.hC.hScan2D.bidirectional;
            scanSettings.activeChannels = obj.channelsToAcquire;
            scanSettings.beamPower= obj.hC.hBeams.powers;
            scanSettings.scanMode= obj.scannerType;
        end %returnScanSettings


        function setUpTileSaving(obj)
            %TODO: add to abstract class
             obj.hC.hScan2D.logFilePath = obj.parent.currentTileSavePath;
             obj.hC.hScan2D.logFileCounter = 1; %Start each section with the index at 1
             obj.hC.hScan2D.logFileStem = sprintf('%s-%04d',obj.parent.recipe.sample.ID,obj.parent.currentSectionNumber); %TODO: replace with something better

             obj.hC.hChannels.loggingEnable = true;
        end %setUpTileSaving


        function initiateTileScan(obj)
            fprintf('Initiating tile scan\n')
            obj.hC.hScan2D.trigIssueSoftwareAcq;
        end


        function maxChans=maxChannelsAvailable(obj)
            maxChans=obj.hC.hChannels.channelsAvailable;
        end %maxChannelsAvailable


        function theseChans = channelsToAcquire(obj)
            theseChans = obj.hC.hChannels.channelSave;
        end %channelsToAcquire

        function scannerType = scannerType(obj)
            scannerType = lower(obj.hC.hScan2D.scannerType);
        end %scannerType

    end %close methods

    methods (Hidden)
        function lastFrameNumber = getLastFrameNumber(obj)
            % Returns the number of frames acquired by the scanner. 
            % In this case it returns the value of "Acqs Done" from the ScanImage main window GUI. 
            lastFrameNumber = obj.scanner.hC.hDisplay.lastFrameNumber;
        end

        function success=toggleUserFunction(obj,UserFcnName,toggleStateTo)
            %find userfunction with UserFcnName and tioggle its Enable state to toggleStateTo
            success=false;
            if isempty(obj.hC.hUserFunctions.userFunctionsCfg)
                disp('ScanImage contains no user functions')
                return
            end

            names={obj.hC.hUserFunctions.userFunctionsCfg.UserFcnName};
            ind=strmatch(UserFcnName,names,'exact');

            if isempty(ind)
                fprintf('Can not find user function name: %s\n',UserFcnName);
                return
            end

            if length(ind)>1
                fprintf('Disabling %d user function with name: "%s"\n', length(ind),UserFcnName);
            end

            for ii=1:length(ind)
                obj.hC.hUserFunctions.userFunctionsCfg(ind(ii)).Enable=toggleStateTo;
            end
            success=true;
        end %toggleUserFunction


        %Listener callback functions
        function updateCurrentZplane(obj,~,~)
            obj.currentZplane=obj.hC.hStackManager.stackSlicesDone+1;
        end %updateCurrentZplane

        function enforceImportantSettings(obj,~,~)
            %Ensure that a few key settings are maintained at the correct values
            if obj.hC.hRoiManager.forceSquarePixels==false
                obj.hC.hRoiManager.forceSquarePixels=true;
            end
            if obj.hC.hScan2D.bidirectional==false
                obj.hC.hScan2D.bidirectional=true;
            end
        end %enforceImportantSettings

    end %hidden methods
end %close classdef
