function settings = readSystemSettings
    % Read system settings
    %
    % function settings = tilerUtils.settings.readSystemSettings
    %
    % Purpose
    % The system settings are those that describe parameters of the rig that are unlikely to 
    % change between sessions. If no settings have been created then the settings directory 
    % made and a default settings file is created. The user is prompted to edit it and nothing
    % is returned. If a settings file is present and looks identical to the default on, the user 
    % is prompted to edit it and nothing is returned. Otherwise the settings file is read and 
    % returned as a structure. 
    % 


    settings=[];
    systemType='sitilter'; %This isn't in the YAML because the user should not change it
    systemVersion=0.5; %This isn't in the YAML because the user should not change it

    settingsDir = tilerUtils.settings.settingsLocation;


    settingsFile = fullfile(settingsDir,'systemSettings.yml');

    DEFAULT_SETTINGS = default_BT_Settings;
    if ~exist(settingsFile)
        fprintf('Can not find system settings file. Making default file at %s\n', settingsFile)
        fprintf('Edit this file and try again\n')
        tilerUtils.yaml.WriteYaml(settingsFile,DEFAULT_SETTINGS);
        return
    end



    settings = tilerUtils.yaml.ReadYaml(settingsFile);

    %Check if the loaded settings are the same as the default settings
    if isequal(settings,DEFAULT_SETTINGS)
        fprintf('\nFound settings file at %s\nThis settings file has not been edited! Edit file for your system and try again.\n', settingsFile)
        settings=[];
        return
    end




    % Make sure all settings that are returned are valid
    % If they are not, we replace them with the original default value

    allValid=true;

    if ~ischar(settings.SYSTEM.ID)
        fprintf('SYSTEM.ID should be a string. Setting it to "%s"\n',DEFAULT_SETTINGS.SYSTEM.ID)
        settings.SYSTEM.ID = DEFAULT_SETTINGS.SYSTEM.ID;
        allValid=false;
    end

    if ~isnumeric(settings.SYSTEM.xySpeed)
        fprintf('SYSTEM.xySpeed should be a number. Setting it to %0.2f \n',DEFAULT_SETTINGS.SYSTEM.xySpeed)
        settings.SYSTEM.xySpeed = DEFAULT_SETTINGS.SYSTEM.xySpeed;
        allValid=false;
    elseif settings.SYSTEM.xySpeed<=0
        fprintf('SYSTEM.xySpeed should be >0. Setting it to %0.2f \n',DEFAULT_SETTINGS.SYSTEM.xySpeed)
        settings.SYSTEM.xySpeed = DEFAULT_SETTINGS.SYSTEM.xySpeed;
        allValid=false;
    end

    if ~isnumeric(settings.SYSTEM.objectiveZSettlingDelay)
        fprintf('SYSTEM.objectiveZSettlingDelay should be a number. Setting it to %0.2f \n',DEFAULT_SETTINGS.SYSTEM.objectiveZSettlingDelay)
        settings.SYSTEM.objectiveZSettlingDelay = DEFAULT_SETTINGS.SYSTEM.objectiveZSettlingDelay;
        allValid=false;
    elseif settings.SYSTEM.objectiveZSettlingDelay<0
        fprintf('SYSTEM.objectiveZSettlingDelay should not be <0. Setting it to %0.2f \n',DEFAULT_SETTINGS.SYSTEM.objectiveZSettlingDelay)
        settings.SYSTEM.objectiveZSettlingDelay = DEFAULT_SETTINGS.SYSTEM.objectiveZSettlingDelay;
        allValid=false;
    end

    if ~allValid
        fprintf('\n ********************************************************************\n')
        fprintf(' * YOU HAVE INVALID VALUES IN %s (see above). \n', settingsFile)
        fprintf(' * You should correct these. \n', settingsFile)
        fprintf(' **********************************************************************\n')
    end


    %Add in the hard-coded settings
    settings.SYSTEM.type=systemType;
    settings.SYSTEM.version=systemVersion;
    