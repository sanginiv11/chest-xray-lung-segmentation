clc;
clear;
close all;

%% ============================================================
%  MONTGOMERY DATASET - AUTOMATIC LUNG SEGMENTATION EVALUATION
% =============================================================

%% 1. Select Montgomery CXR_png folder

datasetFolder = uigetdir('', ...
    'Select the MontgomerySet/CXR_png folder');

if isequal(datasetFolder, 0)
    disp('No dataset folder selected.');
    return;
end

%% 2. Define mask folders

datasetRoot = fileparts(datasetFolder);

leftMaskFolder = fullfile(datasetRoot, 'ManualMask', 'LeftMask');
rightMaskFolder = fullfile(datasetRoot, 'ManualMask', 'RightMask');

%% 3. Get all X-ray images

imageFiles = dir(fullfile(datasetFolder, '*.png'));

numImages = length(imageFiles);

fprintf('\nTotal X-ray images found: %d\n', numImages);

%% 4. Create result arrays

diceScores = zeros(numImages, 1);
iouScores = zeros(numImages, 1);

validImages = false(numImages, 1);

%% 5. Process every X-ray

for k = 1:numImages

    fprintf('\nProcessing image %d of %d...\n', k, numImages);

    %% Get X-ray filename

    fileName = imageFiles(k).name;

    fprintf('Image: %s\n', fileName);

    %% Read X-ray

    I = imread(fullfile(datasetFolder, fileName));

    %% Convert to grayscale

    I = im2gray(I);

    %% CLAHE enhancement

    enhanced = adapthisteq(I);

    %% Wiener filtering

    filtered = wiener2(enhanced, [5 5]);

    %% Canny edge detection

    edges = edge(filtered, 'Canny');

    %% ========================================================
    % AUTOMATIC LUNG SEGMENTATION
    % =========================================================

    threshold = graythresh(filtered);

    segmented = imbinarize(filtered, threshold);

    %% Invert if necessary

    if mean(segmented(:)) > 0.5
        segmented = ~segmented;
    end

    %% Remove border-connected regions

    segmented = imclearborder(segmented);

    %% Fill holes

    segmented = imfill(segmented, 'holes');

    %% Morphological closing

    se = strel('disk', 5);

    segmented = imclose(segmented, se);

    %% Keep two largest regions

    segmented = bwareafilt(segmented, 2);

    %% Morphological cleaning

    se2 = strel('disk', 3);

    cleaned = imopen(segmented, se2);
    cleaned = imclose(cleaned, se2);

    %% ========================================================
    % LOAD REFERENCE MASKS
    % =========================================================

    leftMaskPath = fullfile(leftMaskFolder, fileName);
    rightMaskPath = fullfile(rightMaskFolder, fileName);

    %% Check whether masks exist

    if ~isfile(leftMaskPath) || ~isfile(rightMaskPath)

        fprintf('Masks not found for %s - skipped.\n', fileName);

        continue;

    end

    %% Read masks

    leftMask = imread(leftMaskPath);
    rightMask = imread(rightMaskPath);

    %% Convert to logical

    leftMask = logical(leftMask);
    rightMask = logical(rightMask);

    %% Combine left and right masks

    lungMask = leftMask | rightMask;

    %% Make sure dimensions match

    if ~isequal(size(cleaned), size(lungMask))

        lungMask = imresize(lungMask, size(cleaned), ...
            'nearest');

    end

    %% ========================================================
    % CALCULATE DICE
    % =========================================================

    automaticMask = logical(cleaned);

    intersection = automaticMask & lungMask;

    denominator = nnz(automaticMask) + nnz(lungMask);

    if denominator > 0

        diceScore = ...
            2 * nnz(intersection) / denominator;

    else

        diceScore = 0;

    end

    %% ========================================================
    % CALCULATE IoU
    % =========================================================

    unionMask = automaticMask | lungMask;

    if nnz(unionMask) > 0

        iouScore = nnz(intersection) / nnz(unionMask);

    else

        iouScore = 0;

    end

    %% Store results

    diceScores(k) = diceScore;

    iouScores(k) = iouScore;

    validImages(k) = true;

    fprintf('Dice = %.4f | IoU = %.4f\n', ...
        diceScore, iouScore);

end

%% ============================================================
% FINAL RESULTS
% =============================================================

%% Keep only successfully processed images

validDice = diceScores(validImages);
validIoU = iouScores(validImages);

validNames = {imageFiles(validImages).name}';

%% Create results table

resultsTable = table( ...
    validNames, ...
    validDice, ...
    validIoU, ...
    'VariableNames', ...
    {'ImageName', 'Dice', 'IoU'});

%% Display results

fprintf('\n============================================\n');
fprintf('       MONTGOMERY DATASET RESULTS\n');
fprintf('============================================\n');

disp(resultsTable);

%% Calculate averages

averageDice = mean(validDice);

averageIoU = mean(validIoU);

fprintf('\nAverage Dice = %.4f\n', averageDice);

fprintf('Average IoU  = %.4f\n', averageIoU);

fprintf('============================================\n');

%% Save results to Excel

writetable(resultsTable, ...
    'Montgomery_Segmentation_Results.xlsx');

fprintf('\nResults saved to:\n');
fprintf('Montgomery_Segmentation_Results.xlsx\n');
