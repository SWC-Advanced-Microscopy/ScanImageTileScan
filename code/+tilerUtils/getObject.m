function hT = getObject(quiet)
% Returns the tiler object from the base workspace regardless of its name
%
% Inputs
% quiet - false by default. If true, print no messages to screen. 
%
% Outputs
% hT - the BakingTray object. Returns empty if BT could not be found. 


    if nargin<1
        quiet=false;
    end

    W=evalin('base','whos');

    varClasses = {W.class};

    objName='tiler';
    ind=strmatch(objName,varClasses);

    if isempty(ind)
        if ~quiet
            fprintf('No %s object in base workspace\n',objName)
        end
        hT=[];
        return
    end

    if length(ind)>1
        if ~quiet
            fprintf('More than one %s object in base workspace\n',objName)
        end
        hT=[];
        return
    end


    hT=evalin('base',W(ind).name);