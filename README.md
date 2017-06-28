# ScanImage TileScanner
This package implements a simple time-lapse tile scanner for ScanImage.
It uses linear stages controlled externally to ScanImage. 
We implemented this because we wanted to move the sample on an X/Y stage separate to that which ScanImage controlled.
The software is very specific to our use-case but might be helpful for others. 
Based upon our [motion control](https://github.com/BaselLaserMouse/MotionControl) package. 

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
