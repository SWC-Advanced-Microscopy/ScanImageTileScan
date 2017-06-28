function installPath = installLocation
    % Return install location of the Tiler package
    %
    % function installPath = tilerUtils.settings.installLocation
    %
    %
    % Purpose
    % Return the full path to the install location of the Tiler package.
    % Returns an empty string on error.
    % 
    % Inputs
    % None
    %
    % Outputs
    % installPath - String defining path to install location. 
    %               Empty if something went wrong.
    %
    %
    % 


    pth = which('startTiler');

    installPath = regexprep(pth,['code\',filesep,'startTiler\.m'],''); %Strip the end of the path. 

    if ~exist(installPath,'dir')
        fprintf('Install location expected at %s but not found there\n',installPath)
        installPath=[];
    end

