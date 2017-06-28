function [thisRecipe,recipeFile] = readDefaultRecipe
    % Read the default recipe from the settings directory if missing, add one 
    %
    %   function thisRecipe = tilerUtils.settings.readDefaultRecipe
    %
    % Purpose
    % The recipe is the set of parameters that describe how an acquisition will
    % proceed. This function loads a default recipe. Returns empty if thre is a 
    % problem reading the file. 
    %



    settingsDir = tilerUtils.settings.settingsLocation;
    if isempty(settingsDir)
        return
    end

    if ~exist('settingsDir')
        tilerUtils.settings.readSystemSettings; %get user to make the settings file first
        return
    end


    recipeFile = fullfile(settingsDir,'default_recipe.yml');

    if ~exist(recipeFile,'file')
        fprintf('tilerUtils.settings.readDefaultRecipe is creating a default recipe at %s\n', recipeFile);
        D=defaultRecipe;
        tilerUtils.yaml.WriteYaml(recipeFile,D);        
    end

    thisRecipe = tilerUtils.settings.readRecipe(recipeFile);
