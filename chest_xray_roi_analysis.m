clc;
clear;
close all;

%% ============================================================
% CHEST X-RAY ROI / POTENTIAL ABNORMALITY ANALYSIS
% Classical Digital Image Processing Approach
% =============================================================

%% 1. Select Chest X-ray

[file, path] = uigetfile( ...
    {'*.jpg;*.jpeg;*.png', 'Chest X-ray Images'}, ...
    'Select Chest X-ray');

if isequal(file, 0)
    disp('No X-ray selected.');
    return;
end

I = imread(fullfile(path, file));

%% 2. Convert to Grayscale

I = im2gray(I);

%% 3. Contrast Enhancement using CLAHE

enhanced = adapthisteq(I);

%% 4. Noise Removal using Wiener Filter

filtered = wiener2(enhanced, [5 5]);

%% ============================================================
% 5. IMPROVED LUNG SEGMENTATION
% =============================================================

% Normalize image
normalized = mat2gray(filtered);

% Image dimensions
[rows, cols] = size(normalized);

% Create central chest region
chestRegion = false(rows, cols);

chestRegion( ...
    round(0.08 * rows):round(0.92 * rows), ...
    round(0.12 * cols):round(0.88 * cols)) = true;

% Calculate threshold inside chest region
threshold = graythresh(normalized(chestRegion));

% Segment darker lung regions
segmented = normalized < threshold;

% Restrict to chest region
segmented = segmented & chestRegion;

% Remove small objects
segmented = bwareaopen( ...
    segmented, ...
    round(0.01 * rows * cols));

% Morphological closing
se = strel('disk', 7);

segmented = imclose(segmented, se);

% Fill holes
segmented = imfill(segmented, 'holes');

% Keep two largest regions
segmented = bwareafilt(segmented, 2);

%% 6. Morphological Cleaning

se2 = strel('disk', 3);

lungMask = imopen(segmented, se2);
lungMask = imclose(lungMask, se2);

%% ============================================================
% 7. EXTRACT LUNG REGION
% =============================================================

% Convert image to double
filteredDouble = mat2gray(filtered);

% Keep only pixels inside lung regions
lungRegion = filteredDouble;

lungRegion(~lungMask) = 0;

%% ============================================================
% 8. LOCAL CONTRAST ANALYSIS
% =============================================================

% Calculate local mean intensity
localMean = imgaussfilt(filteredDouble, 15);

% Calculate local contrast
localContrast = abs(filteredDouble - localMean);

% Keep contrast information only inside lungs
contrastMap = localContrast;

contrastMap(~lungMask) = 0;

% Normalize
contrastMap = mat2gray(contrastMap);

%% ============================================================
% 9. EDGE DENSITY ANALYSIS
% =============================================================

% Canny edge detection
edges = edge(filtered, 'Canny');

% Keep edges inside lung regions
lungEdges = edges & lungMask;

% Smooth edge information to create an edge-density map
edgeDensity = imgaussfilt(double(lungEdges), 12);

% Normalize
edgeDensity = mat2gray(edgeDensity);

%% ============================================================
% 10. COMBINE CONTRAST + EDGE INFORMATION
% =============================================================

% Weighted combination
roiScore = 0.6 * contrastMap + ...
           0.4 * edgeDensity;

% Keep only lung regions
roiScore(~lungMask) = 0;

% Normalize final ROI score
roiScore = mat2gray(roiScore);

%% ============================================================
% 11. SELECT HIGH-INTEREST REGIONS
% =============================================================

% Automatically determine threshold
roiThreshold = graythresh(roiScore(lungMask));

% Create potential ROI mask
potentialROI = roiScore > roiThreshold;

% Restrict to lungs
potentialROI = potentialROI & lungMask;

% Remove very small regions
potentialROI = bwareaopen( ...
    potentialROI, ...
    round(0.002 * rows * cols));

%% ============================================================
% 12. MORPHOLOGICAL CLEANING OF ROI
% =============================================================

roiSE = strel('disk', 3);

potentialROI = imclose(potentialROI, roiSE);

potentialROI = imopen(potentialROI, roiSE);

%% ============================================================
% 13. CREATE HIGHLIGHTED ROI IMAGE
% =============================================================

% Convert grayscale image to RGB
highlightedImage = repmat(enhanced, [1 1 3]);

% Highlight potential ROI regions
redChannel = highlightedImage(:,:,1);
greenChannel = highlightedImage(:,:,2);
blueChannel = highlightedImage(:,:,3);

redChannel(potentialROI) = 255;
greenChannel(potentialROI) = 0;
blueChannel(potentialROI) = 0;

highlightedImage(:,:,1) = redChannel;
highlightedImage(:,:,2) = greenChannel;
highlightedImage(:,:,3) = blueChannel;

%% ============================================================
% 14. CALCULATE ROI STATISTICS
% =============================================================

lungArea = nnz(lungMask);

roiArea = nnz(potentialROI);

if lungArea > 0
    roiPercentage = ...
        (roiArea / lungArea) * 100;
else
    roiPercentage = 0;
end

%% ============================================================
% 15. DISPLAY RESULTS
% =============================================================

figure('Name', ...
    'Chest X-ray ROI Analysis', ...
    'NumberTitle', 'off');

subplot(2,4,1);
imshow(I);
title('Original X-ray');

subplot(2,4,2);
imshow(enhanced);
title('CLAHE Enhanced');

subplot(2,4,3);
imshow(lungMask);
title('Lung Segmentation');

subplot(2,4,4);
imshow(lungRegion);
title('Extracted Lung Region');

subplot(2,4,5);
imshow(contrastMap);
title('Local Contrast Map');

subplot(2,4,6);
imshow(edgeDensity);
title('Edge Density Map');

subplot(2,4,7);
imshow(potentialROI);
title('Potential ROI');

subplot(2,4,8);
imshow(highlightedImage);
title('ROI Highlighted');

%% ============================================================
% 16. DISPLAY NUMERICAL RESULTS
% =============================================================

fprintf('\n============================================\n');
fprintf('       CHEST X-RAY ROI ANALYSIS\n');
fprintf('============================================\n');

fprintf('Lung Area              : %d pixels\n', lungArea);
fprintf('Potential ROI Area     : %d pixels\n', roiArea);
fprintf('ROI Percentage         : %.2f %%\n', roiPercentage);

fprintf('============================================\n');

%% ============================================================
% 17. DISPLAY ROI SCORE
% =============================================================

figure('Name', ...
    'Potential Abnormality / ROI Score', ...
    'NumberTitle', 'off');

imshow(roiScore, []);

colorbar;

title('Potential Abnormality / ROI Score');
