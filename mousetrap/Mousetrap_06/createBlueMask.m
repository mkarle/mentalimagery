function [BW,maskedRGBImage] = createBlueMask(RGB)
%createMask  Threshold RGB image using auto-generated code from colorThresholder app.
%  [BW,MASKEDRGBIMAGE] = createMask(RGB) thresholds image RGB using
%  auto-generated code from the colorThresholder App. The colorspace and
%  minimum/maximum values for each channel of the colorspace were set in the
%  App and result in a binary mask BW and a composite image maskedRGBImage,
%  which shows the original RGB image values under the mask BW.

%------------------------------------------------------


% Convert RGB image to chosen color space
RGB = im2double(RGB);
cform = makecform('srgb2lab', 'AdaptedWhitePoint', whitepoint('D65'));
I = applycform(RGB,cform);

% Define thresholds for channel 1 based on histogram settings
channel1Min = 0.000;
channel1Max = 70.604;

% Define thresholds for channel 2 based on histogram settings
channel2Min = -28.547;
channel2Max = 65.213;

% Define thresholds for channel 3 based on histogram settings
channel3Min = -94.892;
channel3Max = -22.959;

% Create mask based on chosen histogram thresholds
BW = (I(:,:,1) >= channel1Min ) & (I(:,:,1) <= channel1Max) & ...
    (I(:,:,2) >= channel2Min ) & (I(:,:,2) <= channel2Max) & ...
    (I(:,:,3) >= channel3Min ) & (I(:,:,3) <= channel3Max);

% Initialize output masked image based on input image.
maskedRGBImage = RGB;

% Set background pixels where BW is false to zero.
maskedRGBImage(repmat(~BW,[1 1 3])) = 0;
