clc;
clear;
close all;

%% ============================================================
% ROI ANALYSIS VISUALIZATION
% Displays only the ROI-related processing stages
% ============================================================

%% 1. SELECT CHEST X-RAY

[file, path] = uigetfile( ...
    {'*.jpg;*.jpeg;*.png', 'Chest X-ray Images'}, ...
    'Select Chest X-ray');

if isequal(file, 0)
    disp('No X-ray selected.');
    return;
end

I_original = imread(fullfile(path, file));

%% 2. GRAYSCALE

I = im2gray(I_original);

%% 3. CLAHE

enhanced = adapthisteq(I);

%% 4. WIENER FILTERING

filtered = wiener2(enhanced, [5 5]);

%% 5. LUNG SEGMENTATION

normalized = mat2gray(filtered);

[rows, cols] = size(normalized);

chestRegion = false(rows, cols);

chestRegion( ...
    round(0.08 * rows):round(0.92 * rows), ...
    round(0.12 * cols):round(0.88 * cols)) = true;

threshold = graythresh(normalized(chestRegion));

segmented = normalized < threshold;

segmented = segmented & chestRegion;

segmented = bwareaopen( ...
    segmented, ...
    round(0.01 * rows * cols));

se = strel('disk', 7);

segmented = imclose(segmented, se);

segmented = imfill(segmented, 'holes');

segmented = bwareafilt(segmented, 2);

%% 6. MORPHOLOGICAL CLEANING

se2 = strel('disk', 3);

lungMask = imopen(segmented, se2);

lungMask = imclose(lungMask, se2);

%% 7. EXTRACTED LUNG REGION

lungImage = normalized;

lungImage(~lungMask) = 0;

%% ============================================================
% ROI ANALYSIS
% ============================================================

%% 8. LOCAL CONTRAST

localMean = imgaussfilt(normalized, 20);

localContrast = abs(normalized - localMean);

localContrast(~lungMask) = 0;

localContrast = mat2gray(localContrast);

%% 9. LOCAL TEXTURE

localStd = stdfilt( ...
    normalized, ...
    true(9));

localStd = mat2gray(localStd);

localStd(~lungMask) = 0;

%% 10. CANNY EDGE ANALYSIS

edges = edge(filtered, 'Canny');

lungEdges = edges & lungMask;

edgeImage = double(lungEdges);

edgeDensity = imgaussfilt( ...
    edgeImage, ...
    10);

edgeDensity = mat2gray(edgeDensity);

%% 11. RIB SUPPRESSION

horizontalSE = strel('line', 15, 0);

ribLikeStructures = imopen( ...
    lungEdges, ...
    horizontalSE);

ribMap = double(ribLikeStructures);

ribMap = imgaussfilt( ...
    ribMap, ...
    5);

ribMap = mat2gray(ribMap);

%% 12. COMBINED ROI SCORE

roiScore = ...
    0.45 * localContrast + ...
    0.35 * localStd + ...
    0.20 * edgeDensity;

% Penalize strong rib-like responses

roiScore = roiScore .* ...
    (1 - 0.5 * ribMap);

% Keep only lung regions

roiScore(~lungMask) = 0;

% Normalize

roiScore = mat2gray(roiScore);

%% 13. SELECT HIGH-SCORE ROI CANDIDATES

lungScores = roiScore(lungMask);

if isempty(lungScores)

    scoreThreshold = 1;

    candidateROI = false(size(roiScore));

else

    scoreThreshold = prctile( ...
        lungScores, 85);

    candidateROI = ...
        roiScore >= scoreThreshold;

    candidateROI = ...
        candidateROI & lungMask;

end

%% 14. REMOVE SMALL ROI REGIONS

minimumArea = round( ...
    0.0015 * rows * cols);

candidateROI = bwareaopen( ...
    candidateROI, ...
    minimumArea);

%% 15. MERGE NEARBY ROI REGIONS

mergeSE = strel('disk', 10);

candidateROI = imclose( ...
    candidateROI, ...
    mergeSE);

%% 16. REMOVE VERY LARGE REGIONS

CC = bwconncomp(candidateROI);

if CC.NumObjects > 0

    stats = regionprops( ...
        CC, ...
        roiScore, ...
        'Area', ...
        'MeanIntensity', ...
        'MaxIntensity', ...
        'BoundingBox', ...
        'Centroid');

    maximumArea = ...
        0.12 * nnz(lungMask);

    keep = false(1, CC.NumObjects);

    for k = 1:CC.NumObjects

        if stats(k).Area <= maximumArea
            keep(k) = true;
        end

    end

    refinedROI = false(size(candidateROI));

    for k = 1:CC.NumObjects

        if keep(k)

            refinedROI( ...
                CC.PixelIdxList{k}) = true;

        end

    end

else

    refinedROI = false(size(candidateROI));

end

%% 17. FINAL ROI SELECTION

CC = bwconncomp(refinedROI);

if CC.NumObjects > 0

    stats = regionprops( ...
        CC, ...
        roiScore, ...
        'Area', ...
        'MeanIntensity', ...
        'MaxIntensity', ...
        'BoundingBox', ...
        'Centroid');

    rankingScore = ...
        zeros(1, CC.NumObjects);

    for k = 1:CC.NumObjects

        rankingScore(k) = ...
            stats(k).MeanIntensity * ...
            log(1 + stats(k).Area);

    end

    [~, order] = sort( ...
        rankingScore, ...
        'descend');

    numberToKeep = ...
        min(3, length(order));

    selectedLabels = ...
        order(1:numberToKeep);

    finalROI = false(size(refinedROI));

    for k = 1:numberToKeep

        labelIndex = selectedLabels(k);

        finalROI( ...
            CC.PixelIdxList{labelIndex}) = true;

    end

else

    stats = [];

    numberToKeep = 0;

    selectedLabels = [];

    finalROI = false(size(refinedROI));

end

%% 18. CREATE FINAL ROI HIGHLIGHT IMAGE

highlightedImage = ...
    repmat(enhanced, [1 1 3]);

highlightedImage = ...
    im2uint8(highlightedImage);

redChannel = highlightedImage(:,:,1);
greenChannel = highlightedImage(:,:,2);
blueChannel = highlightedImage(:,:,3);

redChannel(finalROI) = 255;
greenChannel(finalROI) = 0;
blueChannel(finalROI) = 0;

highlightedImage(:,:,1) = redChannel;
highlightedImage(:,:,2) = greenChannel;
highlightedImage(:,:,3) = blueChannel;

%% ============================================================
% ONE ROI-ONLY FIGURE
% ============================================================

figure( ...
    'Name', 'ROI Analysis', ...
    'NumberTitle', 'off', ...
    'Color', 'black');

tiledlayout(2,3, ...
    'TileSpacing', 'compact', ...
    'Padding', 'compact');

%% 1. Extracted Lung

nexttile;

imshow(lungImage, []);

title( ...
    '1. Extracted Lung Region', ...
    'FontSize', 13, ...
    'FontWeight', 'bold', ...
    'Color', 'white');

%% 2. Local Contrast

nexttile;

imshow(localContrast, []);

title( ...
    '2. Local Contrast', ...
    'FontSize', 13, ...
    'FontWeight', 'bold', ...
    'Color', 'white');

%% 3. Local Texture

nexttile;

imshow(localStd, []);

title( ...
    '3. Local Texture', ...
    'FontSize', 13, ...
    'FontWeight', 'bold', ...
    'Color', 'white');

%% 4. Edge Density

nexttile;

imshow(edgeDensity, []);

title( ...
    '4. Edge Density', ...
    'FontSize', 13, ...
    'FontWeight', 'bold', ...
    'Color', 'white');

%% 5. Combined ROI Score

nexttile;

imagesc(roiScore);

axis image;
axis off;

colorbar;

title( ...
    '5. Combined ROI Score', ...
    'FontSize', 13, ...
    'FontWeight', 'bold', ...
    'Color', 'white');

%% 6. Final ROI Highlighting

nexttile;

imshow(highlightedImage);

hold on;

for k = 1:numberToKeep

    labelIndex = selectedLabels(k);

    rectangle( ...
        'Position', ...
        stats(labelIndex).BoundingBox, ...
        'EdgeColor', 'r', ...
        'LineWidth', 2);

    centroid = ...
        stats(labelIndex).Centroid;

    text( ...
        centroid(1), ...
        centroid(2), ...
        sprintf('ROI %d', k), ...
        'Color', 'y', ...
        'FontSize', 12, ...
        'FontWeight', 'bold', ...
        'HorizontalAlignment', 'center');

end

hold off;

title( ...
    '6. Final ROI Highlighting', ...
    'FontSize', 13, ...
    'FontWeight', 'bold', ...
    'Color', 'white');

sgtitle( ...
    'ROI-BASED LUNG ANALYSIS', ...
    'FontSize', 18, ...
    'FontWeight', 'bold', ...
    'Color', 'white');

%% ============================================================
% ROI STATISTICS
% ============================================================

lungArea = nnz(lungMask);

roiArea = nnz(finalROI);

if lungArea > 0
    roiPercentage = ...
        (roiArea / lungArea) * 100;
else
    roiPercentage = 0;
end

fprintf('\n');
fprintf('============================================\n');
fprintf('          ROI ANALYSIS RESULTS\n');
fprintf('============================================\n');

fprintf( ...
    'Input Image       : %s\n', ...
    file);

fprintf( ...
    'Lung Area         : %d pixels\n', ...
    lungArea);

fprintf( ...
    'Selected ROI Area : %d pixels\n', ...
    roiArea);

fprintf( ...
    'ROI Percentage    : %.2f %%\n', ...
    roiPercentage);

fprintf( ...
    'Selected ROIs     : %d\n', ...
    numberToKeep);

fprintf( ...
    'ROI Threshold     : %.4f\n', ...
    scoreThreshold);

fprintf('============================================\n');