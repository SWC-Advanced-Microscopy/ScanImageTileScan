function component = buildMotionComponent(controllerName,controllerParams,varargin)
% Build  motion component
%
%   function buildMotionComponent(controllerName,controllerParams,stageName1,stageParams1,...stageNameN,stageParamsN)
%
%
% Purpose
% Construct a motion hardware component object from one of the available classes,
% feeding in whatever input arguments are necessary. Returns the constructed
% motion object incorporating both a linearcontroller and one or more linearstages. 
%
% Inputs
% controllerName    - string defining the name of the class to build
% controllerParams  - a structure containing the settings to be applied to the controller 
% stageName         - a string defining the name of the stage class to attach to the controller
% stageParams       - a structure containing the settings to be applied to the stage
% 
% multiple stage/params can be added to a single controller
%
%
% Outputs
% component - A composite motion component object comprised of a stage controller 
%             with attached stages. This object has class "linearcontroller"
%
%
%
% Rob Campbell, Basel - 2016


if nargin<4
    fprintf('%s needs at least four input arguments. QUITTING\n',mfilename)
    return
end

if ~ischar(controllerName)
    fprintf('%s - argument "controllerName" should be a string. SKIPPING CONSTRUCTION OF COMPONENT\n', mfilename)
    component=[];
    return
end

if ~isstruct(controllerParams)
    fprintf('%s - argument "controllerParams" should be a structure. SKIPPING CONSTRUCTION OF COMPONENT\n', mfilename)
    component=[];
    return
end

if ~isfield(controllerParams,'connectAt')
    fprintf('%s - second argument should be the  controller connection parameters. SKIPPING CONSTRUCTION OF COMPONENT\n', mfilename)
end


if mod(length(varargin),2) ~= 0
    fprintf('Stage input aruments should come in pairs. e.g. -\n{''myStage'',struct(''minPos'',-10,''maxPos'',10)\n')
    return
end
stages = reshape(varargin,2,[])'; %so each row is one stage .


% The available controller components 
controllerSuperClassName = 'linearcontroller'; %The name of the abstract class that all controller components must inherit



%Build the correct object based on "controllertName"
component = [];
switch controllerName
    case 'C891'
        stageComponents = build_C891_stages(stages);
        if isempty(stageComponents)
            return
        end

        component = C891(stageComponents);
        
        controllerID.interface='usb';
        controllerID.ID=controllerParams.connectAt;
        component.connect(controllerID); %Connect to the controller

    otherwise
        fprintf('ERROR: unknown motion controller component "%s" SKIPPING BUILDING\n', controllerName)
        component=[];
        return

end


% Do not return component if it's not of the correct class. 
% e.g. this can happen if the class doesn't inherit the correct abstract class
if ~isa(component,controllerSuperClassName)
    fprintf('ERROR in %s:\n constructed component %s is not of class %s. It is a %s. SKIPPING BUILDING.\n', ...
     mfilename, controllerName, controllerSuperClassName, class(component));
    delete(component) %To clean up any open ports, etc
end




%----------------------------------------------------------------------------------------------------
function stageComponents = build_C891_stages(stages)
    %Returns a structure of stage components for the PI C891

    stageComponents=[];
    if size(stages,1)>1
        fprintf('%s - The C891 can only handle one stage. You defined %d stages\n',mfilename,size(stages,1))
        return
    end

    stageComponentName = stages{1,1};
    stageSettings = stages{1,2};

    if ~checkArgs(stageComponentName,stageSettings)
        return
    end

    switch stageComponentName
        case 'genericPIstage'
            stageComponents=genericPIstage;

            %Optionally invert the stage coordinates
            if stageSettings.invertAxis
                stageComponents.stageComponents(ii).transformDistance = @(x) -1*x; 
            end

            %User settings
            stageComponents.axisName=stageSettings.axisName;
            stageComponents.minPos=stageSettings.minPos;
            stageComponents.maxPos=stageSettings.maxPos;
        otherwise
           fprintf('%s - Unknown C891 stage component: %s -- SKIPPING\n',mfilename,stageComponentName)
    end


function success = checkArgs(stageComponentName,stageSettings)
    % Check whether the stageComponent name and stageSettings structure are correct. 
    % i.e. are they the right type and do they look like they contain plausible contents
    if ~ischar(stageComponentName)
        fprintf('Can not build stage. Stage component name is a %s. Expected a string\n', class(stageComponentName))
        success=false;
        return
    end

    if ~isstruct(stageSettings)
        fprintf('Can not build stage. Stage component settings is a %s. Expected a structure\n', class(stageSettings))
        success=false;
        return
    end

    if ~isfield(stageSettings,'axisName') || ~isfield(stageSettings,'minPos') || ~isfield(stageSettings,'maxPos') 
        fprintf('%s - stageSettings of %s do not appear valid: \n',mfilename,stageComponentName)
        disp(stageSettings)
        fprintf('Settings must have fields: axisName, minPos, and maxPos\n')
        fprintf('QUITTING\n')
        success=false;
        return
    end

    success=true;
