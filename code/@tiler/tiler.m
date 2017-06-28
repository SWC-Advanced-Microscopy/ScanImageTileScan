classdef tiler < handle
% tiler
% 
% This the master microscope control class for the tile scanning
% 
% e.g.
%  B=buildDummyControllers;
%  hTT=tiler(B);
%  hT.attachRecipe('recipe_example.yml');
%
% 
% Rob Campbell - Mrsic-Flogel Lab, Basel


    properties (Transient)
        scanner % The object that handles the scanning (e.g. SIBT, our scanImage wrapper)
        recipe  % The details for the experiment go here
        xAxis
        yAxis
        mylistener
    end %close properties


    properties (Hidden)
        % TODO: these should be moved elsewhere. 
        saveToDisk = 1 %By default we save to disk when running
    end

    properties (SetAccess=immutable,Hidden)
        componentSettings
    end


    properties (Hidden)
        buildFailed=true        % True if tiler failed to build all components
        importLastFrames=true   % If true, we keep a copy of the frames acquired at the last X/Y position in obj.downSampledTileBuffer
        processLastFrames=true; % If true we downsample, these frames, rotate, calculate averages, or similar TODO: define this
    end


    %The following are counters and temporary variables used during acquistion
    properties (Hidden,SetObservable,AbortSet,Transient)
        currentTileSavePath     % The path to which data are being saved (see obj.defineSavePath)
        currentSectionNumber
        currentTilePosition=1   % The current index in the X/Y grid. This is used by the scanimage user function to know where in the grid we are
        positionArray           % Array of stage positions that we save to disk
        lastTilePos =  struct('X',0,'Y',0);
        lastTileIndex = 0; %This tells us which row in the tile pattern the last tile came from
    end



    methods
        %Constructor
        function obj=tiler
            clc
            fprintf('Starting...\n')
            % Check if an instance already exists and return *that*.
            W=evalin('base','whos');
            varClasses = {W.class};
            ind=strmatch('tiler',varClasses);

            if ~isempty(ind)
                fprintf('An instance of tiler already exists in the base workspace.\n')
                obj=evalin('base',W(ind).name);
                return
            end

            % Read component settings
            obj.componentSettings=tilerUtils.settings.readComponentSettings;


            fprintf('\n\n Connecting to hardware components:\n\n')

            try
                success=obj.attachMotionAxes(obj.componentSettings.motionAxis);
            catch ME1
                disp(ME1.message)
                success=false;
            end

            if ~success
                fprintf('Failed to build one or more axes. Quitting.\n')
                delete(obj);
                return
            end

            %Attach the default recipe
            obj.attachRecipe;

            % Read the stage positions so they are stored in the stage objects. This ensures that any 
            % methods that might rely on the stage currentPosition properties aren't fed an empty array.
            obj.getXYpos;

            obj.buildFailed=false;
        end %Constructor

        %Destructor
        function obj=delete(obj) 
            if obj.isXaxisConnected
                obj.xAxis.delete
            end
            if obj.isYaxisConnected
                obj.yAxis.delete
            end
        end  %Destructor


        %TODO: declare external methods


        % ----------------------------------------------------------------------
        % Public methods for moving the X/Y stage
        function varargout=moveXYto(obj,xPos,yPos,blocking,extraSettlingTime,timeOut)
            % Absolute move position defined by xPos and yPos
            % Wait for motion to complete before returning if blocking is true. 
            % blocking is false by default.
            % extraSettlingTime is an additional waiting period after the end of a blockin motion.
            % This extra wait is used when tile scanning to ensure that vibration has ceased. zero by default.
            % timeOut (inf by default) if true, we don't wait longer than
            % this many seconds for motion to complete
            %
            % moveXYto(obj,xPos,yPos,blocking,extraSettlingTime,timeOut)
            if nargin<3
                success=false;
                fprintf('moveXYto expects two input arguments: xPos and yPos in mm -- NOT MOVING\n')
                return
            end
            if nargin<4
                blocking=false;
            end
            if nargin<5
                extraSettlingTime=0;
            end
            if nargin<6
                timeOut=inf;
            end

            success=obj.moveXto(xPos) & obj.moveYto(yPos);

            if blocking && success
                obj.waitXYsettle(extraSettlingTime,timeOut)
            end

            if nargout>0
                varargout{1}=success;
            end
        end

        function varargout=moveXYby(obj,xPos,yPos,blocking,extraSettlingTime,timeOut)
            % Relative move defined by xPos and yPos
            % Wait for motion to complete before returning if blocking is true. 
            % blocking is false by default.
            % extraSettlingTime is an additional waiting period after the end of a blockin motion.
            % This extra wait is used when tile scanning to ensure that vibration has ceased. zero by default.
            % timeOut (inf by default) if true, we don't wait longer than
            % this many seconds for motion to complete
            %
            % varargout=moveXYby(obj,xPos,yPos,blocking,extraSettlingTime,timeOut)
            if nargin<3
                success=false;
                fprintf('moveXYby expects two input arguments: xPos and yPos in mm -- NOT MOVING\n')
                return
            end
            if nargin<4
                blocking=false;
            end
            if nargin<5
                extraSettlingTime=0;
            end
            if nargin<6
                timeOut=inf;
            end

            success = obj.moveXby(xPos) & obj.moveYby(yPos);

            if blocking && success
                obj.waitXYsettle(extraSettlingTime,timeOut)
            end

            if nargout>0
                varargout{1}=success;
            end
        end

        function waitXYsettle(obj,extraSettlingTime,timeOut)
            % Purpose
            % Blocks whilst either of the stages is moving then, optionally,
            % waits extraSettlingTime seconds then returns. There is also 
            % an option to time-out if the motion reports as incomplete.
            %
            % waitXYsettle(obj,extraSettlingTime,timeOut)
            %
            % By default, extraSettlingTime is zero and timeOut is
            % infinite. Currently this is implemented only for relative and
            % absolute X/Y motions. 
            if nargin<2
                extraSettlingTime=0;
            end
            if nargin<3
                timeOut=inf;
            end


            tic

            while obj.isXYmoving
                pause(0.05)
                if toc>timeOut
                    disp('Timed out waiting for motion to complete')
                    break
                end
            end %while
            pause(extraSettlingTime)
        end %waitXYsettle

        function isMoving = isXYmoving(obj)
            %returns true if either the x or y axis is currently moving

            xM=obj.xAxis.isMoving;
            yM=obj.yAxis.isMoving;
            isMoving = yM | xM;
        end

        function success=stopXY(obj)
            success = obj.xAxis.stopAxis & obj.yAxis.stopAxis;
        end



        % ----------------------------------------------------------------------
        % Public methods for moving the X/Y stage with respect to the sample
        function success = toFrontLeft(obj)
            %Move stage to the front left position (the starting position for a grid tile scan)
            success=false;
            if isempty(obj.recipe)
                return
            end

            FL = obj.recipe.FrontLeft;
            if isempty(FL.X) || isempty(FL.Y)
                fprintf('Front/Left position has not been set.')
                return
            end
            success=obj.moveXYto(FL.X,FL.Y,true); %blocking motion
        end



        % ----------------------------------------------------------------------
        % Convenience methods to query axis position 
        function pos = getXpos(obj)
            pos=obj.xAxis.axisPosition;
        end

        function pos = getYpos(obj)
            pos=obj.yAxis.axisPosition;
        end

        function varargout = getXYpos(obj)
            %print to screen if no outputs asked for
            X=obj.getXpos;
            Y=obj.getYpos;
            if nargout<1
            	fprintf('X=%0.2f, Y=%0.2f\n',X,Y)
            	return
            end
            if nargout>0
            	varargout{1}=X;
            end
            if nargout>1
            	varargout{2}=Y;
            end
        end


        % ----------------------------------------------------------------------
        % Convenience methods to get or set properties of the stage motions:
        % maxSpeed and acceleration
        function vel = getXvelocity(obj)
            vel=obj.xAxis.getMaxVelocity;
        end

        function vel = getYvelocity(obj)
            vel=obj.yAxis.getMaxVelocity;
        end

        function varargout = setXvelocity(obj,velocity)
            success=obj.xAxis.setMaxVelocity(velocity);
            if nargout>0
                varargout{1}=success;
            end
        end

        function varargout = setYvelocity(obj,velocity)
            success=obj.yAxis.setMaxVelocity(velocity);
            if nargout>0
                varargout{1}=success;
            end
        end
        
        function varargout = setXYvelocity(obj,velocity)
            sX=obj.xAxis.setMaxVelocity(velocity);
            sY=obj.yAxis.setMaxVelocity(velocity);
            success = sX & sY;
            if nargout>0
                varargout{1}=success;
            end
        end


    end %close methods


    methods (Hidden)
        % ----------------------------------------------------------------------
        % Convenience motion methods
        % The following are convenience methods so we don't have to specify
        % the stage identity each time. This is just the price of having a more
        % flexible system and allowing for the possibility of multiple stages per
        % controller, even though systems we work with don't have this. 

        % - - -  Absolute moves - - - 
        function success = moveXto(obj,position,blocking)
            if nargin<3, blocking=0; end
            success=obj.xAxis.absoluteMove(position);
            if ~success, return, end

            if blocking
                while obj.xAxis.isMoving
                    pause(0.05)
                end
            end
        end %moveXto

        function success = moveYto(obj,position,blocking)
            if nargin<3, blocking=0; end
            success=obj.yAxis.absoluteMove(position);
            if ~success, return, end

            if blocking
                while obj.yAxis.isMoving
                    pause(0.05)
                end
            end
        end %moveYto


        % - - -  Relative moves - - - 
        function success = moveXby(obj,distanceToMove,blocking)
            if nargin<3, blocking=0; end
            success=obj.xAxis.relativeMove(distanceToMove);
            if ~success, return, end
            if blocking
                while obj.xAxis.isMoving
                    pause(0.05)
                end
            end
        end %moveXby

        function success = moveYby(obj,distanceToMove,blocking)
            if nargin<3, blocking=0; end
            success=obj.yAxis.relativeMove(distanceToMove);
            if ~success, return, end
            if blocking
                while obj.yAxis.isMoving
                    pause(0.05)
                end
            end
        end %moveYby


        %House-keeping functions
        function msg = checkForPrepareComponentsThatAreNotConnected(obj)
            %Returns empty if everything is connected. Otherwise returns 
            %message string detailing what the problem is. This is used
            %by view classes to display error messages. 
            msg=[];
            if ~obj.isRecipeConnected
                msg =[msg,'No recipe connected\n'];
            end
            if ~obj.isXaxisConnected
                msg =[msg,'No X stage connected\n'];
            end
            if ~obj.isYaxisConnected
                msg =[msg,'No Y stage connected\n'];
            end
        end

        function isConnected=isScannerConnected(obj)
            isConnected=obj.isComponentConnected('scanner');
        end %isScannerConnected

        function isConnected=isRecipeConnected(obj)
            isConnected=obj.isComponentConnected('recipe');
        end %isRecipeConnected

        function isConnected=isXaxisConnected(obj)
            isConnected=obj.isComponentConnected('xAxis','linearcontroller');
        end %isXaxisConnected

        function isConnected=isYaxisConnected(obj)
            isConnected=obj.isComponentConnected('yAxis','linearcontroller');
        end %isYaxisConnected

        function isConnected=isComponentConnected(obj,componentName,componentClass)
            % Return true if component defined by string "componentName" is connected
            if nargin<3
                componentClass=componentName;
            end
            isConnected=false;
            if ~isempty(obj.(componentName)) && isa(obj.(componentName),componentClass) && isvalid(obj.(componentName))
                isConnected=true;
            else
                isConnected=false;
            end
        end %isComponentConnected

    end % close hidden methods (motion)

    
end %close classdef