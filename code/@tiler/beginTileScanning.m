function beginTileScanning(obj)
    % Runs a tile scan multiple times
    %
    % function tiler.beginTileScanning


    if ~obj.isScannerConnected 
        fprintf('No scanner connected.\n')
        return
    end

    if ~isa(obj.scanner,'SIBT')
        fprintf('Only acquisition with ScanImage supported at the moment.\n')
        return
    end


    obj.recipe.tilePattern; %Generate the tile pattern 

    % ----------------------------------------------------------------------------
    %Check whether the acquisition is likely to fail in some way
    [acqPossible,msg]=obj.checkIfAcquisitionIsPossible;
    if ~acqPossible
        fprintf(msg)
        return
    end


    %Define an anonymous function to nicely print the current time
    currentTimeStr = @() datestr(now,'yyyy/mm/dd HH:MM:SS');


    fprintf('Setting up acquisition of sample %s\n',obj.recipe.sample.ID)


    %----------------------------------------------------------------------------------------

    fprintf('Starting data acquisition\n')
    obj.currentTileSavePath=[];
    tidy = onCleanup(@() beginTileScanningCleanupFun(obj));


    %Log the current time to the recipe
    obj.recipe.Acquisition.acqStartTime = currentTimeStr();

    %loop and tile scan
    for ii=1:obj.recipe.mosaic.numSections

        startTime=now;

        if obj.saveToDisk
            if ~obj.defineSavePath
                %Detailed warnings produced by defineSavePath method
                disp('Acquisition stopped: save path not defined');
                return 
            end
            obj.scanner.setUpTileSaving;
        end

        if ~obj.scanner.armScanner;
            disp('FAILED TO START -- COULD NOT ARM SCANNER')
            return
        end

        if ~obj.runTileScan
            return
        end

    end % for ii=1:obj.recipe.mosaic.numSections

end


function beginTileScanningCleanupFun(obj)
    %Perform clean up functions
    obj.scanner.disarmScanner;
    obj.lastTilePos.X=0;
    obj.lastTilePos.Y=0;
end 
