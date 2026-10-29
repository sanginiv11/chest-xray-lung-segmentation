clc;
clear;
close all;

%% 1. Select Chest X-ray
[file, path] = uigetfile({'*.jpg;*.jpeg;*.png', 'Image Files'}, ...
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

%% 5. Edge Detection using Canny
edges = edge(filtered, 'Canny');

%% 6. Automatic Lung Segmentation

% Calculate automatic threshold
threshold = graythresh(filtered);

% Convert image to binary
segmented = imbinarize(filtered, threshold);

% Make dark lung regions the foreground
if mean(segmented(:)) > 0.5
    segmented = ~segmented;
end

% Remove regions connected to image borders
segmented = imclearborder(segmented);

% Fill holes inside lung regions
segmented = imfill(segmented, 'holes');

% Smooth and connect regions
se = strel('disk', 5);
segmented = imclose(segmented, se);

% Keep the two largest connected regions
segmented = bwareafilt(segmented, 2);

%% 7. Morphological Cleaning

se2 = strel('disk', 3);

cleaned = imopen(segmented, se2);
cleaned = imclose(cleaned, se2);

%% 8. Display DIP Processing Results

figure;

subplot(2,3,1);
imshow(I);
title('Original X-ray');

subplot(2,3,2);
imshow(enhanced);
title('CLAHE Enhanced');

subplot(2,3,3);
imshow(filtered);
title('Wiener Filter');

subplot(2,3,4);
imshow(edges);
title('Canny Edge Detection');

subplot(2,3,5);
imshow(segmented);
title('Automatic Lung Segmentation');

subplot(2,3,6);
imshow(cleaned);
title('Morphological Cleaning');

%% 9. Select Left Lung Reference Mask

[fileLeft, pathLeft] = uigetfile({'*.png', 'PNG Images'}, ...
    'Select Left Lung Mask');

if isequal(fileLeft, 0)
    disp('No left lung mask selected.');
    return;
end

leftMask = imread(fullfile(pathLeft, fileLeft));

%% 10. Select Right Lung Reference Mask

[fileRight, pathRight] = uigetfile({'*.png', 'PNG Images'}, ...
    'Select Right Lung Mask');

if isequal(fileRight, 0)
    disp('No right lung mask selected.');
    return;
end

rightMask = imread(fullfile(pathRight, fileRight));

%% 11. Convert Reference Masks to Logical

leftMask = logical(leftMask);
rightMask = logical(rightMask);

%% 12. Combine Left and Right Lung Masks

lungMask = leftMask | rightMask;

%% 13. Display Reference Lung Mask

figure;

imshow(lungMask);
title('Reference Lung Mask');

%% 14. Compare X-ray with Reference Mask

figure;

subplot(1,2,1);
imshow(I);
title('Original Chest X-ray');

subplot(1,2,2);
imshow(lungMask);
title('Reference Lung Mask');
%% 15. Compare Automatic Segmentation with Reference Mask

% Use the final cleaned mask as automatic segmentation
automaticMask = logical(cleaned);

% Make sure both masks have the same size
if ~isequal(size(automaticMask), size(lungMask))
    lungMask = imresize(lungMask, size(automaticMask), 'nearest');
end

% Calculate intersection
intersection = automaticMask & lungMask;

% Calculate Dice coefficient
diceScore = 2 * nnz(intersection) / ...
    (nnz(automaticMask) + nnz(lungMask));

% Calculate IoU
unionMask = automaticMask | lungMask;
iouScore = nnz(intersection) / nnz(unionMask);

% Display results
fprintf('\n--- Lung Segmentation Evaluation ---\n');
fprintf('Dice Coefficient : %.4f\n', diceScore);
fprintf('IoU              : %.4f\n', iouScore);

%% 16. Display Automatic vs Reference Mask

figure;

subplot(1,2,1);
imshow(automaticMask);
title('Automatic Lung Mask');

subplot(1,2,2);
imshow(lungMask);
title('Reference Lung Mask');