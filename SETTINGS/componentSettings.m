function settings=componentSettings
    % component settings file for Tiler
    %
    % function settings=componentSettings
    %


    %-------------------------------------------------------------------------------------------
    % Scanner
    % Scanning is achieved using ScanImage 5.2 
    scanner.type='SIBT'; % One of: 'SIBT', 'dummyScanner'
    scanner.settings=[]; %Unused at present




    %-------------------------------------------------------------------------------------------
    % MOTION CONTROLLERS
    % These settings relate to the motion controllers used to translate the sample in X and Y.

    % X axis 
    nC=1;
    motionAxis(nC).type='C891';
    motionAxis(nC).settings.connectAt='116010269';
    motionAxis(nC).stage.type='genericPIstage'; 
    motionAxis(nC).stage.settings.invertAxis=false;
    motionAxis(nC).stage.settings.axisName='xAxis'; 
    motionAxis(nC).stage.settings.minPos = -30;
    motionAxis(nC).stage.settings.maxPos =  65;


    % Y axis
    nC=2;
    motionAxis(nC).type='C891';
    motionAxis(nC).settings.connectAt='116010268';
    motionAxis(nC).stage.type='genericPIstage';
    motionAxis(nC).stage.settings.invertAxis=false;
    motionAxis(nC).stage.settings.axisName='yAxis'; %Only change if you know what you are doing
    motionAxis(nC).stage.settings.minPos = -17;
    motionAxis(nC).stage.settings.maxPos =  13;                                                                   


    %-------------------------------------------------------------------------------------------
    % Assemble the output structure (don't edit this stuff)
    settings.scanner    = scanner;
    settings.motionAxis = motionAxis;
    %-------------------------------------------------------------------------------------------

