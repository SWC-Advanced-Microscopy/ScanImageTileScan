function [settings,pathToFile] = readComponentSettings
    % Read BakingTray component settings
    %
    % function [settings,pathToFile] = tilerUtils.settings.readComponentSettings
    %
    % Purpose
    % The component settings are those that describe which hardware components are available
    % and what are the settings for these. If no component settings have been created then the 
    % settings directory made (if necessary) and a default settings file is created. The user is prompted to edit it and nothing
    % is returned. If a settings file is present and looks identical to the default on, the user 
    % is prompted to edit it and nothing is returned. Otherwise the settings file is read and 
    % returned as a structure. 
    %
    %
    % Outputs
    % settings - a structure containing the settings
    % pathToFile - path to the settings file



    settingsDir = tilerUtils.settings.settingsLocation;
    if isempty(settingsDir)
        return
    end

    settings=[];

    pathToFile = fullfile(settingsDir,'componentSettings.m');

    if ~exist(pathToFile,'file')
        error('Can not find a component settings file in %s%s\n', settingsDir,filesep)
        return
    end


    % For neatness we don't have the settings directory in the path, so we
    % cd to it, run it, then return to the current directory. 
    CWD=pwd;
    cd(settingsDir);
    if exist('./componentSettings.m','file')
        settings=componentSettings;
    else
        fprintf('Can not find componentSettings.m in %s.\n', settingsDir) %Should be impossible
        return
    end
    cd(CWD)

    if isempty(settings.scanner.type)
        fprintf('** Scanner not defined in component settings file\n')
    end

    for ii=length(settings.motionAxis):-1:1
        if isempty(settings.motionAxis(ii).type)
            settings.motionAxis(ii)=[];
        end
        if isempty(settings.motionAxis)
            fprintf('** No motion axes defined\n')
        end
    end
