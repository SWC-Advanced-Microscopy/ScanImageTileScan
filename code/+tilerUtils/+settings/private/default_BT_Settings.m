function settings=default_BT_Settings
    % Return a set of default system settings to write to a file in the settings directoru
    %
    % settings.SYSTEM.ID='SYSTEM_NAME';
    % settings.SYSTEM.xySpeed=100.0; %X/Y stage speed in mm/s
    % settings.SYSTEM.objectiveZSettlingDelay=0.05; %Number of seconds to wait before imaging the next optical plane
    %


    settings.SYSTEM.ID='SYSTEM_NAME';
    settings.SYSTEM.xySpeed=100.0;
    settings.SYSTEM.objectiveZSettlingDelay=0.05;
    settings.SYSTEM.enableFlyBackBlanking=false;
