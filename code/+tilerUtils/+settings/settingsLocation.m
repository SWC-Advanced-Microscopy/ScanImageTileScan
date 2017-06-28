function settingsDir=settingsLocation
    % Return user settings location of the Tiler
    %
	% function settingsDir=settingsLocation
	%



    installDir = tilerUtils.settings.installLocation;
    if isempty(installDir)
    	settingsDir=[];
        return
    end

    settingsDir = fullfile(installDir,'SETTINGS');

    %Make the settings directory if needed
    if ~exist('settingsDir')
        mkdir(settingsDir)
    end

    if ~exist(settingsDir,'dir')
        success=mkdir(settingsDir);
        if ~success
            fprintf('FAILED TO MAKE SETTINGS DIRECTORY: %s. Check the permissions and try again\n', settingsDir);
            return
        end
    end