function success = defineSavePath(obj) 
    %Set up the save file names for this section based on the current recipe
    %
    % function success = defineSavePath
    %
    % Purpose
    % Define the directory into which tiles will be saved and make this directory if needed
    %


    saveDir = sprintf('%s', obj.recipe.sample.ID);

    if ~exist(saveDir,'dir')
        mkdir(saveDir)
    end

    %Bail out if the save directory still does not exist
    if ~exist(saveDir,'dir')
        fprintf('Save file directory %s is missing.',saveDir)
        success=false;
        return
    end

    %set the folder for logging TIFF files
    obj.currentTileSavePath = fullfile(pwd,saveDir);

    success=true;
