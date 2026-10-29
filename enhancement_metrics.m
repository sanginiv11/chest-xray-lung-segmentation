clc;
clear;
close all;

%% ============================================================
% CHEST X-RAY ENHANCEMENT QUALITY EVALUATION
% Metrics:
% 1. Entropy
% 2. RMS Contrast
% 3. Edge Strength
% =============================================================

%% 1. SELECT CHEST X-RAY

[file, path] = uigetfile( ...
    {'*.jpg;*.jpeg;*.png', 'Chest X-ray Images'}, ...
    'Select Chest X-ray');

if isequal(file, 0)
    disp('No X-ray selected.');
    return;
end

I_original = imread(fullfile(path, file));

%% ============================================================
% 2. GRAYSCALE CONVERSION
% =============================================================

I_gray = im2gray(I_original);

%% ============================================================
% 3. CLAHE ENHANCEMENT
% =============================================================

claheImage = adapthisteq(I_gray);

%% ============================================================
% 4. WIENER FILTERING
% =============================================================

wienerImage = wiener2(claheImage, [5 5]);

%% ============================================================
% 5. CONVERT TO DOUBLE
% =============================================================

I = im2double(I_gray);
CLAHE = im2double(claheImage);
WIENER = im2double(wienerImage);

%% ============================================================
% 6. ENTROPY
% ============================================================

entropyOriginal = entropy(I_gray);

entropyCLAHE = entropy(claheImage);

entropyWiener = entropy(wienerImage);

%% ============================================================
% 7. RMS CONTRAST
% ============================================================

contrastOriginal = std(I(:));

contrastCLAHE = std(CLAHE(:));

contrastWiener = std(WIENER(:));

%% ============================================================
% 8. EDGE STRENGTH
% ============================================================

edgesOriginal = edge(I_gray, 'Canny');

edgesCLAHE = edge(claheImage, 'Canny');

edgesWiener = edge(wienerImage, 'Canny');

edgeStrengthOriginal = ...
    nnz(edgesOriginal) / numel(edgesOriginal);

edgeStrengthCLAHE = ...
    nnz(edgesCLAHE) / numel(edgesCLAHE);

edgeStrengthWiener = ...
    nnz(edgesWiener) / numel(edgesWiener);

%% ============================================================
% 9. DISPLAY RESULTS
% ============================================================

fprintf('\n');
fprintf('====================================================\n');
fprintf('       CHEST X-RAY ENHANCEMENT QUALITY\n');
fprintf('====================================================\n');

fprintf('\nInput Image: %s\n\n', file);

fprintf('                    Entropy    RMS Contrast    Edge Strength\n');
fprintf('--------------------------------------------------------------\n');

fprintf('Original             %.4f        %.4f          %.4f\n', ...
    entropyOriginal, ...
    contrastOriginal, ...
    edgeStrengthOriginal);

fprintf('CLAHE                %.4f        %.4f          %.4f\n', ...
    entropyCLAHE, ...
    contrastCLAHE, ...
    edgeStrengthCLAHE);

fprintf('CLAHE + Wiener       %.4f        %.4f          %.4f\n', ...
    entropyWiener, ...
    contrastWiener, ...
    edgeStrengthWiener);

fprintf('====================================================\n');

%% ============================================================
% 10. CREATE RESULTS TABLE
% ============================================================

Method = { ...
    'Original'; ...
    'CLAHE'; ...
    'CLAHE + Wiener'};

Entropy = [ ...
    entropyOriginal; ...
    entropyCLAHE; ...
    entropyWiener];

RMS_Contrast = [ ...
    contrastOriginal; ...
    contrastCLAHE; ...
    contrastWiener];

Edge_Strength = [ ...
    edgeStrengthOriginal; ...
    edgeStrengthCLAHE; ...
    edgeStrengthWiener];

ResultsTable = table( ...
    Method, ...
    Entropy, ...
    RMS_Contrast, ...
    Edge_Strength);

disp(' ');
disp('Enhancement Quality Results:');
disp(ResultsTable);

%% ============================================================
% 11. VISUAL COMPARISON
% ============================================================

figure( ...
    'Name', ...
    'Enhancement Quality Comparison', ...
    'NumberTitle', ...
    'off');

tiledlayout(1,3, ...
    'TileSpacing', 'compact', ...
    'Padding', 'compact');

nexttile;

imshow(I_gray, []);

title( ...
    '1. Original X-ray', ...
    'FontSize', 14, ...
    'FontWeight', 'bold');

nexttile;

imshow(claheImage, []);

title( ...
    '2. CLAHE Enhancement', ...
    'FontSize', 14, ...
    'FontWeight', 'bold');

nexttile;

imshow(wienerImage, []);

title( ...
    '3. CLAHE + Wiener', ...
    'FontSize', 14, ...
    'FontWeight', 'bold');

sgtitle( ...
    'CHEST X-RAY ENHANCEMENT COMPARISON', ...
    'FontSize', 18, ...
    'FontWeight', 'bold');

%% ============================================================
% 12. ENTROPY GRAPH
% ============================================================

figure( ...
    'Name', ...
    'Entropy Comparison', ...
    'NumberTitle', ...
    'off');

bar(Entropy);

set(gca, ...
    'XTick', 1:3, ...
    'XTickLabel', ...
    {'Original', 'CLAHE', 'CLAHE + Wiener'});

ylabel('Entropy');

title( ...
    'Entropy Comparison', ...
    'FontSize', 15, ...
    'FontWeight', 'bold');

grid on;

%% ============================================================
% 13. RMS CONTRAST GRAPH
% ============================================================

figure( ...
    'Name', ...
    'RMS Contrast Comparison', ...
    'NumberTitle', ...
    'off');

bar(RMS_Contrast);

set(gca, ...
    'XTick', 1:3, ...
    'XTickLabel', ...
    {'Original', 'CLAHE', 'CLAHE + Wiener'});

ylabel('RMS Contrast');

title( ...
    'RMS Contrast Comparison', ...
    'FontSize', 15, ...
    'FontWeight', 'bold');

grid on;

%% ============================================================
% 14. EDGE STRENGTH GRAPH
% ============================================================

figure( ...
    'Name', ...
    'Edge Strength Comparison', ...
    'NumberTitle', ...
    'off');

bar(Edge_Strength);

set(gca, ...
    'XTick', 1:3, ...
    'XTickLabel', ...
    {'Original', 'CLAHE', 'CLAHE + Wiener'});

ylabel('Edge Pixel Ratio');

title( ...
    'Edge Strength Comparison', ...
    'FontSize', 15, ...
    'FontWeight', 'bold');

grid on;

%% ============================================================
% 15. SAVE RESULTS
% ============================================================

outputFile = ...
    'Enhancement_Quality_Results.xlsx';

writetable( ...
    ResultsTable, ...
    outputFile);

fprintf('\nResults saved to: %s\n', outputFile);

fprintf('\n');
fprintf('Enhancement quality evaluation completed.\n');
fprintf('====================================================\n');