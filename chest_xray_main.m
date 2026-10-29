clc;
clear;
close all;

% Select Chest X-ray
[file, path] = uigetfile({'*.jpg;*.jpeg;*.png', 'Image Files'});     % using the "uigetfile" version because the we
% won't have to worry about file paths while experimenting with different X-rays.
I = imread(fullfile(path, file));

% Convert to grayscale
I = im2gray(I);

% Contrast enhancement
enhanced = adapthisteq(I);

% Noise removal
filtered = wiener2(enhanced, [5 5]);

% Edge detection
edges = edge(filtered, 'Canny');

% Segmentation
segmented = imbinarize(filtered);

% Morphological cleaning
se = strel('disk', 2);
cleaned = imopen(segmented, se);

% Display
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
title('Edge Detection');

subplot(2,3,5);
imshow(segmented);
title('Segmentation');

subplot(2,3,6);
imshow(cleaned);
title('Morphological Cleaning');
% Select Left Lung Mask
[fileLeft, pathLeft] = uigetfile({'*.png', 'PNG Images'}, ...
    'Select Left Lung Mask');

leftMask = imread(fullfile(pathLeft, fileLeft));

% Select Right Lung Mask
[fileRight, pathRight] = uigetfile({'*.png', 'PNG Images'}, ...
    'Select Right Lung Mask');

rightMask = imread(fullfile(pathRight, fileRight));

% Convert to logical
leftMask = logical(leftMask);
rightMask = logical(rightMask);

% Combine both lungs
lungMask = leftMask | rightMask;

% Display reference lung mask
figure;
imshow(lungMask);
title('Reference Lung Mask');
% Compare X-ray with reference lung mask
figure;

subplot(1,2,1);
imshow(I);
title('Original Chest X-ray');

subplot(1,2,2);
imshow(lungMask);
title('Reference Lung Mask');