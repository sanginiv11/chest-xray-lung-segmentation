clc;
clear;
close all;

%% ============================================================
% MONTGOMERY DATASET
% ENHANCEMENT QUALITY EVALUATION
%
% Metrics:
% 1. Entropy
% 2. RMS Contrast
% 3. Edge Strength
%
% Methods:
% Original
% CLAHE
% CLAHE + Wiener
% =============================================================

%% 1. SELECT CXR_png FOLDER

datasetFolder = uigetdir( ...
    pwd, ...
    'Select Montgomery CXR_png Folder');

if isequal(datasetFolder, 0)
    disp('No dataset folder selected.');
    return;
end

%% ============================================================
% 2. FIND ALL PNG IMAGES
% =============================================================

files = dir(fullfile(datasetFolder, '*.png'));

numberOfImages = length(files);

fprintf('\n');
fprintf('====================================================\n');
fprintf('   MONTGOMERY DATASET ENHANCEMENT QUALITY\n');
fprintf('====================================================\n');

fprintf('Images found: %d\n\n', numberOfImages);

if numberOfImages == 0
    error('No PNG images found in the selected folder.');
end

%% ============================================================
% 3. PREALLOCATE RESULTS
% =============================================================

ImageName = strings(numberOfImages,1);

Entropy_Original = zeros(numberOfImages,1);
Entropy_CLAHE = zeros(numberOfImages,1);
Entropy_Wiener = zeros(numberOfImages,1);

Contrast_Original = zeros(numberOfImages,1);
Contrast_CLAHE = zeros(numberOfImages,1);
Contrast_Wiener = zeros(numberOfImages,1);

Edge_Original = zeros(numberOfImages,1);
Edge_CLAHE = zeros(numberOfImages,1);
Edge_Wiener = zeros(numberOfImages,1);

%% ============================================================
% 4. PROCESS ALL 138 IMAGES
% ============================================================

for k = 1:numberOfImages

    %% Read image

    filename = files(k).name;

    ImageName(k) = filename;

    I_original = imread( ...
        fullfile(datasetFolder, filename));

    %% Convert to grayscale

    I_gray = im2gray(I_original);

    %% Convert to double

    I = im2double(I_gray);

    %% ========================================================
    % CLAHE
    % ========================================================

    claheImage = adapthisteq(I_gray);

    %% ========================================================
    % WIENER FILTER
    % ========================================================

    wienerImage = wiener2( ...
        claheImage, ...
        [5 5]);

    %% Convert processed images

    CLAHE = im2double(claheImage);

    WIENER = im2double(wienerImage);

    %% ========================================================
    % ENTROPY
    % ========================================================

    Entropy_Original(k) = ...
        entropy(I_gray);

    Entropy_CLAHE(k) = ...
        entropy(claheImage);

    Entropy_Wiener(k) = ...
        entropy(wienerImage);

    %% ========================================================
    % RMS CONTRAST
    % Standard deviation of normalized intensity
    % ========================================================

    Contrast_Original(k) = ...
        std(I(:));

    Contrast_CLAHE(k) = ...
        std(CLAHE(:));

    Contrast_Wiener(k) = ...
        std(WIENER(:));

    %% ========================================================
    % EDGE STRENGTH
    % Canny edge pixel ratio
    % ========================================================

    edgesOriginal = ...
        edge(I_gray, 'Canny');

    edgesCLAHE = ...
        edge(claheImage, 'Canny');

    edgesWiener = ...
        edge(wienerImage, 'Canny');

    Edge_Original(k) = ...
        nnz(edgesOriginal) / numel(edgesOriginal);

    Edge_CLAHE(k) = ...
        nnz(edgesCLAHE) / numel(edgesCLAHE);

    Edge_Wiener(k) = ...
        nnz(edgesWiener) / numel(edgesWiener);

    %% Progress

    fprintf( ...
        'Processed %3d / %3d : %s\n', ...
        k, ...
        numberOfImages, ...
        filename);

end

%% ============================================================
% 5. CREATE IMAGE-WISE RESULTS TABLE
% =============================================================

ResultsTable = table( ...
    ImageName, ...
    Entropy_Original, ...
    Entropy_CLAHE, ...
    Entropy_Wiener, ...
    Contrast_Original, ...
    Contrast_CLAHE, ...
    Contrast_Wiener, ...
    Edge_Original, ...
    Edge_CLAHE, ...
    Edge_Wiener);

%% ============================================================
% 6. CALCULATE MEAN AND STANDARD DEVIATION
% =============================================================

meanEntropyOriginal = mean(Entropy_Original);
stdEntropyOriginal = std(Entropy_Original);

meanEntropyCLAHE = mean(Entropy_CLAHE);
stdEntropyCLAHE = std(Entropy_CLAHE);

meanEntropyWiener = mean(Entropy_Wiener);
stdEntropyWiener = std(Entropy_Wiener);


meanContrastOriginal = mean(Contrast_Original);
stdContrastOriginal = std(Contrast_Original);

meanContrastCLAHE = mean(Contrast_CLAHE);
stdContrastCLAHE = std(Contrast_CLAHE);

meanContrastWiener = mean(Contrast_Wiener);
stdContrastWiener = std(Contrast_Wiener);


meanEdgeOriginal = mean(Edge_Original);
stdEdgeOriginal = std(Edge_Original);

meanEdgeCLAHE = mean(Edge_CLAHE);
stdEdgeCLAHE = std(Edge_CLAHE);

meanEdgeWiener = mean(Edge_Wiener);
stdEdgeWiener = std(Edge_Wiener);

%% ============================================================
% 7. DISPLAY DATASET SUMMARY
% ============================================================

fprintf('\n');
fprintf('============================================================\n');
fprintf('           DATASET-LEVEL RESULTS\n');
fprintf('============================================================\n');

fprintf('\nENTROPY\n');
fprintf('Original       : %.4f +/- %.4f\n', ...
    meanEntropyOriginal, stdEntropyOriginal);

fprintf('CLAHE          : %.4f +/- %.4f\n', ...
    meanEntropyCLAHE, stdEntropyCLAHE);

fprintf('CLAHE + Wiener : %.4f +/- %.4f\n', ...
    meanEntropyWiener, stdEntropyWiener);


fprintf('\nRMS CONTRAST\n');
fprintf('Original       : %.4f +/- %.4f\n', ...
    meanContrastOriginal, stdContrastOriginal);

fprintf('CLAHE          : %.4f +/- %.4f\n', ...
    meanContrastCLAHE, stdContrastCLAHE);

fprintf('CLAHE + Wiener : %.4f +/- %.4f\n', ...
    meanContrastWiener, stdContrastWiener);


fprintf('\nEDGE STRENGTH\n');
fprintf('Original       : %.4f +/- %.4f\n', ...
    meanEdgeOriginal, stdEdgeOriginal);

fprintf('CLAHE          : %.4f +/- %.4f\n', ...
    meanEdgeCLAHE, stdEdgeCLAHE);

fprintf('CLAHE + Wiener : %.4f +/- %.4f\n', ...
    meanEdgeWiener, stdEdgeWiener);

fprintf('\n============================================================\n');

%% ============================================================
% 8. SUMMARY TABLE
% =============================================================

Method = { ...
    'Original'; ...
    'CLAHE'; ...
    'CLAHE + Wiener'};

Mean_Entropy = [ ...
    meanEntropyOriginal; ...
    meanEntropyCLAHE; ...
    meanEntropyWiener];

Std_Entropy = [ ...
    stdEntropyOriginal; ...
    stdEntropyCLAHE; ...
    stdEntropyWiener];

Mean_RMS_Contrast = [ ...
    meanContrastOriginal; ...
    meanContrastCLAHE; ...
    meanContrastWiener];

Std_RMS_Contrast = [ ...
    stdContrastOriginal; ...
    stdContrastCLAHE; ...
    stdContrastWiener];

Mean_Edge_Strength = [ ...
    meanEdgeOriginal; ...
    meanEdgeCLAHE; ...
    meanEdgeWiener];

Std_Edge_Strength = [ ...
    stdEdgeOriginal; ...
    stdEdgeCLAHE; ...
    stdEdgeWiener];

SummaryTable = table( ...
    Method, ...
    Mean_Entropy, ...
    Std_Entropy, ...
    Mean_RMS_Contrast, ...
    Std_RMS_Contrast, ...
    Mean_Edge_Strength, ...
    Std_Edge_Strength);

disp(' ');
disp('============================================================');
disp('SUMMARY TABLE');
disp('============================================================');

disp(SummaryTable);

%% ============================================================
% 9. SAVE RESULTS TO EXCEL
% ============================================================

outputFile = fullfile( ...
    pwd, ...
    'Montgomery_Enhancement_Quality_Results.xlsx');

writetable( ...
    ResultsTable, ...
    outputFile, ...
    'Sheet', ...
    'Image-wise Results');

writetable( ...
    SummaryTable, ...
    outputFile, ...
    'Sheet', ...
    'Dataset Summary');

fprintf('\nResults saved to:\n%s\n', outputFile);

%% ============================================================
% 10. ENTROPY GRAPH
% ============================================================

figure( ...
    'Name', ...
    'Dataset Entropy Comparison', ...
    'NumberTitle', ...
    'off');

entropyValues = [ ...
    meanEntropyOriginal, ...
    meanEntropyCLAHE, ...
    meanEntropyWiener];

bar(entropyValues);

set(gca, ...
    'XTick', 1:3, ...
    'XTickLabel', ...
    {'Original', 'CLAHE', 'CLAHE + Wiener'});

ylabel('Mean Entropy');

title( ...
    'Montgomery Dataset - Entropy Comparison', ...
    'FontSize', 15, ...
    'FontWeight', 'bold');

grid on;

%% ============================================================
% 11. EDGE STRENGTH GRAPH
% ============================================================

figure( ...
    'Name', ...
    'Dataset Edge Strength Comparison', ...
    'NumberTitle', ...
    'off');

edgeValues = [ ...
    meanEdgeOriginal, ...
    meanEdgeCLAHE, ...
    meanEdgeWiener];

bar(edgeValues);

set(gca, ...
    'XTick', 1:3, ...
    'XTickLabel', ...
    {'Original', 'CLAHE', 'CLAHE + Wiener'});

ylabel('Mean Edge Pixel Ratio');

title( ...
    'Montgomery Dataset - Edge Strength Comparison', ...
    'FontSize', 15, ...
    'FontWeight', 'bold');

grid on;

%% ============================================================
% 12. RMS CONTRAST GRAPH
% ============================================================

figure( ...
    'Name', ...
    'Dataset RMS Contrast Comparison', ...
    'NumberTitle', ...
    'off');

contrastValues = [ ...
    meanContrastOriginal, ...
    meanContrastCLAHE, ...
    meanContrastWiener];

bar(contrastValues);

set(gca, ...
    'XTick', 1:3, ...
    'XTickLabel', ...
    {'Original', 'CLAHE', 'CLAHE + Wiener'});

ylabel('Mean RMS Contrast');

title( ...
    'Montgomery Dataset - RMS Contrast Comparison', ...
    'FontSize', 15, ...
    'FontWeight', 'bold');

grid on;

%% ============================================================
% 13. COMPLETION MESSAGE
% ============================================================

fprintf('\n');
fprintf('====================================================\n');
fprintf(' Enhancement quality evaluation completed.\n');
fprintf(' Total images processed: %d\n', numberOfImages);
fprintf('====================================================\n');