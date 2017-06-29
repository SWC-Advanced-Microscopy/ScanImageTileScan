# ScanImage TileScanner
This package implements a simple time-lapse tile scanner for [ScanImage](https://vidriotechnologies.com).
The package defines a class called `tiler` that is a wrapper around ScanImage.
`Tiler` sets up tile coordinates, moves an X/Y stage, and instructs ScanImage to take images. 
Image acquisition is performed partly via a ScanImage user-function. 
Multiple repeats (called "sections") of the same tile region can be obtained. 
This allows for things like time-lapse imaging of morphological changes in large brain slices. 

## Limitations
Our approach is useful only for specific cases. 
For instance, we implemented our own [motion control](https://github.com/BaselLaserMouse/MotionControl) classes for this project as we wanted the sample stage to move indepedently from the ScanImage-controlled stage. 
This has the disadvantage that you will need to write your own control code if you don't use the PI C-891 motion controller, as we did here. 
However, it has the advantage that you can set up your system in a very open-ended manner. 
Also note that some settings (e.g. the imagaing depth) are hard-coded. 


## Example session

```
>> startTiler
Starting...


 Connecting to hardware components:

Setting up axis xAxis on linear stage controller C891 #1
PI_MATLAB_Driver_GCS2 loaded successfully.
Attempting to connect to C-891 with serial number 116010269
Setting up axis yAxis on linear stage controller C891 #2
PI_MATLAB_Driver_GCS2 loaded successfully.
Attempting to connect to C-891 with serial number 116010268

Setting sample name to: sample_17-06-28_175354
X=-0.30, Y=2.30


% Now we attach ScanImage to tiler. 
>> scanimage % first start scanimage

>> who

Your variables are:

hSI     hSICtl  hT    


% This step is manual, sorry
>> hT.scanner=SIBT;
>> hT.scanner.parent=hT;


Starting SIBT interface for ScanImage
 - Setting fast z waveform type to "step"
 - Setting up power/depth correction using Lz=180.
   You may change this value in "POWER CONTROLS". (Smaller numbers will increase the power more with depth.)


% Set a 2 by 2 mm area
>> hT.recipe.mosaic.sampleSize.X=2;
>> hT.recipe.mosaic.sampleSize.Y=2;

>> hT.beginTileScanning
Setting up acquisition of sample sample_17-06-28_182233
Starting data acquisition
```
