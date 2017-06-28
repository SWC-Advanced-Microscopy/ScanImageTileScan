function success=checkAttachedStages(obj,ControllerObject,axisName)
    %Check that ControllerObject (which is a linearcontroller we want to attach) 
    %has stages attached to it and is ready to go.
    %If all is good return true, otherwise return false.

    success=false;

    if ~isa(ControllerObject,'linearcontroller')
        DB=dbstack;
        stages=false;
        return
    end

    if ~(ControllerObject.isStageConnected)
        DB=dbstack;
        stages=false;
        return
    end

    if ~ControllerObject.isAxisReady(axisName)
        DB=dbstack;
        stages=false;
        return
    end
    
    success=true;
end