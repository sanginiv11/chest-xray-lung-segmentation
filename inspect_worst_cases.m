clc;
clear;
close all;

%% ============================================================
% INSPECT WORST SEGMENTATION CASES
% Uses the existing Excel results - does NOT rerun the dataset
% =============================================================

%% 1. Select the existing Excel results file

[fileExcel, pathExcel] = uigetfile({'*.xlsx', 'Excel Files'}, ...
    'Select Montgomery_Segmentation_Results.xlsx');

if isequal(fileExcel, 0)
    disp('No Excel file selected.');
    return;
end

%% 2. Read the existing results

resultsTable = readtable(fullfile(pathExcel, fileExcel));

%% 3. Sort images by Dice score

[~, sortedIndex] = sort(resultsTable.Dice, 'ascend');

%% 4. Select the 5 worst cases

numWorst = min(5, height(resultsTable));

worstCases = resultsTable(sortedIndex(1:numWorst), :);

%% 5. Display the worst cases in Command Window

fprintf('\n============================================\n');
fprintf('        5 WORST SEGMENTATION CASES\n');
fprintf('============================================\n');

disp(worstCases);

%% 6. Select Montgomery CXR_png folder

datasetFolder = uigetdir('', ...
    'Select the MontgomerySet/CXR_png folder');

if isequal(datasetFolder, 0)
    disp('No dataset folder selected.');
    return;
end

%% 7. Locate ManualMask folders

datasetRoot = fileparts(datasetFolder);

leftMaskFolder = fullfile(datasetRoot, ...
    'ManualMask', 'LeftMask');

rightMaskFolder = fullfile(datasetRoot, ...
    'ManualMask', 'RightMask');

%% 8. Display each worst case

for n = 1:numWorst

    %% Get filename

    fileName = char(worstCases.ImageName(n));

    fprintf('\nDisplaying worst case %d: %s\n', ...
        n, fileName);

    fprintf('Dice = %.4f\n', worstCases.Dice(n));
    fprintf('IoU  = %.4f\n', worstCases.IoU(n));

    %% Read X-ray

    xrayPath = fullfile(datasetFolder, fileName);

    I = imread(xrayPath);

    I = im2gray(I);

    %% ================================================
    % RECREATE THE AUTOMATIC SEGMENTATION
    % ================================================

    enhanced = adapthisteq(I);

    filtered = wiener2(enhanced, [5 5]);

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

    %% Final morphological cleaning

    se2 = strel('disk', 3);

    automaticMask = imopen(segmented, se2);
    automaticMask = imclose(automaticMask, se2);

    %% ================================================
    % LOAD REFERENCE MASK
    % ================================================

    leftMaskPath = fullfile(leftMaskFolder, fileName);

    rightMaskPath = fullfile(rightMaskFolder, fileName);

    leftMask = logical(imread(leftMaskPath));

    rightMask = logical(imread(rightMaskPath));

    referenceMask = leftMask | rightMask;

    %% ================================================
    % DISPLAY
    % ================================================

    figure('Name', fileName);

    subplot(1,3,1);

    imshow(I);

    title('Original X-ray');

    subplot(1,3,2);

    imshow(automaticMask);

    title(sprintf('Automatic Mask\nDice = %.4f', ...
        worstCases.Dice(n)));

    subplot(1,3,3);

    imshow(referenceMask);

    title(sprintf('Reference Mask\nIoU = %.4f', ...
        worstCases.IoU(n)));

end

fprintf('\n============================================\n');
fprintf('Finished inspecting the 5 worst cases.\n');
fprintf('============================================\n');