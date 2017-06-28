function [acquisitionPossible,msg] = checkIfAcquisitionIsPossible(obj)
    % Check if acquisition is possible 
    %
    % [acquisitionPossible,msg] = checkIfAcquisitionIsPossible(obj)
    %
    % Purpose
    % This method determines whether it is possible to begin an acquisiton. 


    msg='';
    
    % We need a recipe connected and it must indicate that acquisition is possible
    if ~obj.isRecipeConnected
        msg=sprintf('%sNo recipe.\n',msg);
    end

    if ~obj.isRecipeConnected
        msg=sprintf(['%sAcquisition is not currently possible.\n', ...
            'Did you connect a recipe?\n'], msg);
    end

    obj.recipe.checkIfAcquisitionIsPossible;
    if obj.isRecipeConnected && ~obj.recipe.acquisitionPossible
        msg=sprintf(['%sAcquisition is not currently possible.\n', ...
            'Did you connect a recipe?\n'], msg);
    end




    % We need a scanner connected and it must be ready to acquire data
    if ~obj.isScannerConnected
        msg=sprintf('%sNo scanner is connected.\n',msg);
    end

    if obj.isScannerConnected && ~obj.scanner.isReady
        msg=sprintf('Scanner is not ready to acquire data\n');
    end

    %Check the axes are conncted
    if ~obj.isXaxisConnected
        msg=sprintf('%sNo xAxis is connected.\n',msg);
    end
    if ~obj.isYaxisConnected
        msg=sprintf('%sNo yAxis is connected.\n',msg);
    end

    % Ensure that we will display only one channel. This is potentially important for speed reasons
    % TODO: maybe make this a setting?
    if  obj.isScannerConnected && strcmpi(obj.scanner.scannerType,'linear')
        n=length(obj.scanner.channelsToDisplay);
        if n>1
            msg=sprintf(['%sScanImage is currently configured to display %d channels\n',...
                    'Acquisition may be faster with just one channel selected for display.\n', ...
                    'Please go to the CHANNELS window in ScanImage and leave only one channel checked in the "Display" column\n'],msg,n);
        end
    end




    % -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  
    %Set the acquisitionPossible boolean based on whether a message exists
    if isempty(msg)
        acquisitionPossible=true;
    else
        acquisitionPossible=false;
    end


    %Print the message to screen if the user requested no output arguments. 
    if acquisitionPossible==false && nargout<2
        fprintf(msg)
    end

