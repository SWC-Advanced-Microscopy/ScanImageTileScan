function runSuccess = runTileScan(obj)
    % This method inititiates the acquisition of a tile scan for one section
    %
    % function runSuccess = runTileScan(obj)
    % 
    % Purpose
    % The method moves the sample to the front/left position, initialises some variables
    % then initiates the scan cycle. 
    
    runSuccess=false;

    
    %Create the position array
    [pos,indexes]=obj.recipe.tilePattern;
    obj.positionArray = [indexes,pos,nan(size(pos))]; %We will store the stage locations here as we go

    startTime=now;

    obj.toFrontLeft;
    pause(1) %Wait a second for stuff to settle just in case (this may be a fast move)
    
    %Log this first location to disk, otherwise it won't be recorded.
    obj.currentTilePosition=1;
    obj.logPositionToPositionArray;

    obj.scanner.initiateTileScan; %acquires a stack and triggers scanimage to acquire the rest of the stacks
    
    %block until done
    while 1
        if ~obj.scanner.isAcquiring
            break
        end
        
        pause(1)
    end



    %Report the total time
    totalTime = now-startTime;
    totalTime = totalTime*24*60^2;
    fprintf('\nFinished %d tiles (%d x %d x %d) in %0.1f seconds (%0.2f s per tile)\n\n',...
        obj.recipe.numTilesInPhysicalSection, ....
        obj.recipe.NumTiles.X, obj.recipe.NumTiles.Y, obj.recipe.mosaic.numOpticalPlanes, ...
        totalTime, totalTime/obj.recipe.numTilesInPhysicalSection)
    runSuccess=true;

