function startTiler
    % Creates a instance of the tiler class and places it in the base workspace as hT
    %
    % function startTiley(varargin)
    %
    % Purpose
    % Tiler startup function. Starts hT if it is not already started.
    %
    
    if ~isSafeToMake_hT
        return
    end

  
    %Does am object already exist in the base workspace?
    hT=tilerUtils.getObject(true);

    if isempty(hT)
        %If not, we build it
        try
            hT = tiler;
            assignin('base','hT',hT)
        catch ME
            fprintf('Build of tiler object "hT" failed\n')
            delete(hT)
            rethrow(ME)
            return
        end
    end %if isempty(hT)


    if hT.buildFailed
        fprintf('startTiler failed to create an instance of hT. Quitting.\n')
        evalin('base','clear hT')
        return
    end %if hT.buildFailed


    fprintf('Tiler has started\n')
    %That was easy!






%-------------------------------------------------------------------------------------------------------------------------
function safe = isSafeToMake_hT
    W=evalin('base','whos');

    if strmatch('hT',{W.name})
        fprintf('For access to the, API, startTiler creates a variable called "hT" in the base workspace.\n')
        fprintf('A variable by this name already exists. Please remove this variable and run "BakingTray" again\n')
        safe=false;
    else
        safe=true;
    end
