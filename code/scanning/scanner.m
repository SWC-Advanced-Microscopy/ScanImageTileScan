classdef (Abstract) scanner < handle
%%  scanner
%
% The scanner abstract class declares methods to obtain an image.
%
%
% Rob Campbell - Basel 2016

    properties 
        hC      %A handle to scan object's API.
    end %close public properties
    
    properties (Hidden)
        parent  %A copy of the parent object
        currentZplane
        type
        settings
    end

    % These are GUI-related properties. The view class that comprises the GUI listens to changes in these
    % properties to know when to update the GUI. It is therefore necessary for these to be updated as 
    % appropriate by classes which inherit scanner. e.g. the isAcquiring method should update isScannerAcquiring
    properties (Hidden, SetObservable, AbortSet)
        isScannerAcquiring %True if scanner is acquiring data
    end

    % The following are all critical methods that your class should define
    % You should also define a suitable destructor to clean up after you class
    methods (Abstract)

        success = connect(obj,API)
        % connect
        %
        % Behavior
        % This method establishes a connection between the concrete object and the 
        % API of the software that controls the scanner.
        %
        % Inputs
        % API - connect this API to the scanner object
        %
        % Outputs
        % success - true or false depending on whether a connection was established


        ready = isReady(obj)
        % isReady
        %
        % Behavior
        % Returns true if the scanner is ready to acquire data. False Otherwise
        % TODO: I need a better definition of "ready"
        %
        % Inputs
        % None
        % 
        % Outputs
        % ready - true or false 


        success = armScanner(obj)
        % armScanner
        % 
        % Behavior
        % This method is called after scanner.isReady and sets up the 
        % acquisition. It is expected this would be called before the 
        % start of each new physical section. e.g. this method might 
        % ensure that the scan parameters are at their correct values, 
        % ensure the scan software is in the correct mode to acquire 
        % the next section, etc. 
        %
        % Outputs
        % returns true or false depending on whether or not all steps
        % conducted by the method ran succesfully. 


        success = disarmScanner(obj)
        % disarmScanner
        % 
        % Behavior
        % This method is called when acquisition finishes (or aborted early).
        % Not all all scanners will need this. This method may do things such as 
        % as return the scanner to user control rather than remote control. To
        % stop scanning run scanner.abortScanning
        %
        % Outputs
        % returns true or false depending on whether or not all steps
        % conducted by the method ran succesfully. 

        abortScanning(obj)
        % abortScanning
        %
        % Behavior
        % Causes the scanning to stop immediately but does not perform any further
        % operations (like restoring scan settings) since these are done by 
        % scanner.disarmScanner

        acquiring = isAcquiring(obj)
        % isAcquiring
        %
        % Behavior
        % Returns true if the scanner object is in an active, data-acquiring, mode. 
        %
        %
        % Inputs
        % None
        %
        % Output
        % acquiring - true/false

        initiateTileScan(obj)
        % initiateTileScan
        %
        % Behavior
        % This method is called once to initiate scanning of tiles. 


        scanSettings = returnScanSettings(obj)
        % returnScanSettings
        %
        % Behavior
        % reads key scan settings from the scanning software and returns them as a structure.
        % This method must return at least the following:
        % OUT.pixelsPerLine - number of pixels on each line of each tile as it's saved to disk
        % OUT.linesPerFrame - number of lines in each tile as it's saved to disk
        % OUT.micronsBetweenOpticalPlanes - number of microns separating one optical plane from the other (zero if none)
        % OUT.FOV_alongColsinMicrons - Number of imaged microns along the columns (within a line) of the image (to 2 decimal places)
        % OUT.FOV_alongRowsinMicrons - Number of imaged microns along the rows (the lines) of the image (to 2 decimal places)
        % OUT.micronsPerPixel_cols   - The number of microns per pixel along the columns (to 3 decimal places)
        % OUT.micronsPerPixel_rows   - The number of microns per pixel along the rows (to 3 decimal places)
        %
        % Other fields may be returned too if desired. But the above are the only critical ones.


        maxChannelsAvailable(obj)
        % maxChannelsAvailable
        %
        % Behavior
        % Returns an integer that defines the maximum number of channels the scanner can handle. 
        % So even if only one channel is being used, if the scanner can handle 4 channels then
        % the output of maxChannelsAvailable will be 4. 

        channelsToAcquire(obj)
        % channelsToAcquire
        % 
        % Behavior
        % Return the indexes of the channels which are active and will be saved to disk. 
        % e.g. if channels one and three are to be saved to disk this method should be [1,3]

        scannerType(obj)
        % scannerType
        %
        % Behavior
        % Returns a string describing the type of scanner. Should be either 'linear' or 'resonant'


     end %close methods

end %close classdef