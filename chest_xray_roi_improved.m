clc;
clear;
close all;

%% ============================================================
% CHEST X-RAY ROI / POTENTIAL ABNORMALITY ANALYSIS
% Classical Digital Image Processing Approach
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
% 2. CONVERT TO GRAYSCALE
% =============================================================

I = im2gray(I_original);

%% ============================================================
% 3. CLAHE CONTRAST ENHANCEMENT
% =============================================================

enhanced = adapthisteq(I);

%% ============================================================
% 4. WIENER FILTERING
% =============================================================

filtered = wiener2(enhanced, [5 5]);

%% ============================================================
% 5. IMPROVED LUNG SEGMENTATION
% =============================================================

normalized = mat2gray(filtered);

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

% Restrict to chest
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

%% ============================================================
% 6. MORPHOLOGICAL CLEANING
% =============================================================

se2 = strel('disk', 3);

lungMask = imopen(segmented, se2);
lungMask = imclose(lungMask, se2);

%% ============================================================
% 7. EXTRACT LUNG REGION
% =============================================================

lungImage = normalized;

lungImage(~lungMask) = 0;

%% ============================================================
% 8. LOCAL CONTRAST ANALYSIS
% =============================================================

localMean = imgaussfilt(normalized, 20);

localContrast = abs(normalized - localMean);

localContrast(~lungMask) = 0;

localContrast = mat2gray(localContrast);

%% ============================================================
% 9. LOCAL TEXTURE ANALYSIS
% =============================================================

localStd = stdfilt( ...
    normalized, ...
    true(9));

localStd = mat2gray(localStd);

localStd(~lungMask) = 0;

%% ============================================================
% 10. CANNY EDGE ANALYSIS
% =============================================================

edges = edge(filtered, 'Canny');

lungEdges = edges & lungMask;

edgeImage = double(lungEdges);

edgeDensity = imgaussfilt( ...
    edgeImage, ...
    10);

edgeDensity = mat2gray(edgeDensity);

%% ============================================================
% 11. SUPPRESS STRONG RIB-LIKE RESPONSE
% =============================================================

horizontalSE = strel('line', 15, 0);

ribLikeStructures = imopen( ...
    lungEdges, ...
    horizontalSE);

ribMap = double(ribLikeStructures);

ribMap = imgaussfilt( ...
    ribMap, ...
    5);

ribMap = mat2gray(ribMap);

%% ============================================================
% 12. COMBINED ROI SCORE
% =============================================================

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

%% ============================================================
% 13. SELECT HIGH-SCORE ROI CANDIDATES
% =============================================================

lungScores = roiScore(lungMask);

if isempty(lungScores)

    scoreThreshold = 1;
    candidateROI = false(size(roiScore));

else

    % Select top 15% of ROI scores
    scoreThreshold = prctile( ...
        lungScores, 85);

    candidateROI = ...
        roiScore >= scoreThreshold;

    candidateROI = ...
        candidateROI & lungMask;

end

%% ============================================================
% 14. REMOVE SMALL ROI REGIONS
% =============================================================

minimumArea = round( ...
    0.0015 * rows * cols);

candidateROI = bwareaopen( ...
    candidateROI, ...
    minimumArea);

%% ============================================================
% 15. MERGE NEARBY ROI REGIONS
% =============================================================

mergeSE = strel('disk', 10);

candidateROI = imclose( ...
    candidateROI, ...
    mergeSE);

%% ============================================================
% 16. REMOVE VERY LARGE REGIONS
% =============================================================

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

    % Maximum acceptable ROI size
    maximumArea = ...
        0.12 * nnz(lungMask);

    keep = false(1, CC.NumObjects);

    for k = 1:CC.NumObjects

        if stats(k).Area <= maximumArea
            keep(k) = true;
        end

    end

    refinedROI = false( ...
        size(candidateROI));

    for k = 1:CC.NumObjects

        if keep(k)

            refinedROI( ...
                CC.PixelIdxList{k}) = true;

        end

    end

else

    refinedROI = false( ...
        size(candidateROI));

end

%% ============================================================
% 17. FINAL CONNECTED COMPONENT ANALYSIS
% =============================================================

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

    % Calculate ranking score
    rankingScore = ...
        zeros(1, CC.NumObjects);

    for k = 1:CC.NumObjects

        rankingScore(k) = ...
            stats(k).MeanIntensity * ...
            log(1 + stats(k).Area);

    end

    % Sort strongest to weakest
    [~, order] = sort( ...
        rankingScore, ...
        'descend');

    % Keep maximum 3 strongest ROIs
    numberToKeep = ...
        min(3, length(order));

    selectedLabels = ...
        order(1:numberToKeep);

    finalROI = false( ...
        size(refinedROI));

    for k = 1:numberToKeep

        labelIndex = ...
            selectedLabels(k);

        finalROI( ...
            CC.PixelIdxList{labelIndex}) = true;

    end

else

    stats = [];

    rankingScore = [];

    numberToKeep = 0;

    selectedLabels = [];

    finalROI = false( ...
        size(refinedROI));

end

%% ============================================================
% 18. CREATE ROI HIGHLIGHT IMAGE
% =============================================================

highlightedImage = ...
    repmat(enhanced, [1 1 3]);

% Convert to uint8 for reliable highlighting
highlightedImage = ...
    im2uint8(highlightedImage);

redChannel = ...
    highlightedImage(:,:,1);

greenChannel = ...
    highlightedImage(:,:,2);

blueChannel = ...
    highlightedImage(:,:,3);

% Highlight selected ROI pixels in red
redChannel(finalROI) = 255;
greenChannel(finalROI) = 0;
blueChannel(finalROI) = 0;

highlightedImage(:,:,1) = redChannel;
highlightedImage(:,:,2) = greenChannel;
highlightedImage(:,:,3) = blueChannel;

%% ============================================================
% 19. DISPLAY TOP ROI BOUNDING BOXES
% =============================================================

figure( ...
    'Name', ...
    'Potential High-Interest Regions', ...
    'NumberTitle', ...
    'off');

imshow(enhanced, []);

title( ...
    'Top Potential High-Interest ROIs', ...
    'FontSize', 15, ...
    'FontWeight', 'bold');

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

%% ============================================================
% 20. COMPLETE LABELLED DIP PIPELINE
% ============================================================

figure( ...
    'Name', ...
    'Chest X-ray Digital Image Processing Pipeline', ...
    'NumberTitle', ...
    'off');

% Use tiledlayout for clearer spacing
tiledlayout(3,4, ...
    'TileSpacing', 'compact', ...
    'Padding', 'compact');

% ------------------------------------------------------------
% 1. Original X-ray
% ------------------------------------------------------------

nexttile;

imshow(I_original, []);

title( ...
    '1. Original X-ray', ...
    'FontSize', 12, ...
    'FontWeight', 'bold');

% ------------------------------------------------------------
% 2. Grayscale
% ------------------------------------------------------------

nexttile;

imshow(I, []);

title( ...
    '2. Grayscale Conversion', ...
    'FontSize', 12, ...
    'FontWeight', 'bold');

% ------------------------------------------------------------
% 3. CLAHE
% ------------------------------------------------------------

nexttile;

imshow(enhanced, []);

title( ...
    '3. CLAHE Enhancement', ...
    'FontSize', 12, ...
    'FontWeight', 'bold');

% ------------------------------------------------------------
% 4. Wiener Filter
% ------------------------------------------------------------

nexttile;

imshow(filtered, []);

title( ...
    '4. Wiener Filtering', ...
    'FontSize', 12, ...
    'FontWeight', 'bold');

% ------------------------------------------------------------
% 5. Canny
% ------------------------------------------------------------

nexttile;

imshow(edges);

title( ...
    '5. Canny Edge Detection', ...
    'FontSize', 12, ...
    'FontWeight', 'bold');

% ------------------------------------------------------------
% 6. Lung Segmentation
% ------------------------------------------------------------

nexttile;

imshow(lungMask);

title( ...
    '6. Lung Segmentation', ...
    'FontSize', 12, ...
    'FontWeight', 'bold');

% ------------------------------------------------------------
% 7. Extracted Lung
% ------------------------------------------------------------

nexttile;

imshow(lungImage, []);

title( ...
    '7. Extracted Lung Region', ...
    'FontSize', 12, ...
    'FontWeight', 'bold');

% ------------------------------------------------------------
% 8. Local Contrast
% ------------------------------------------------------------

nexttile;

imshow(localContrast, []);

title( ...
    '8. Local Contrast Analysis', ...
    'FontSize', 12, ...
    'FontWeight', 'bold');

% ------------------------------------------------------------
% 9. Local Texture
% ------------------------------------------------------------

nexttile;

imshow(localStd, []);

title( ...
    '9. Local Texture Analysis', ...
    'FontSize', 12, ...
    'FontWeight', 'bold');

% ------------------------------------------------------------
% 10. Edge Density
% ------------------------------------------------------------

nexttile;

imshow(edgeDensity, []);

title( ...
    '10. Edge Density Analysis', ...
    'FontSize', 12, ...
    'FontWeight', 'bold');

% ------------------------------------------------------------
% 11. ROI Score
% ------------------------------------------------------------

nexttile;

imagesc(roiScore);

axis image;
axis off;

colorbar;

title( ...
    '11. Combined ROI Score', ...
    'FontSize', 12, ...
    'FontWeight', 'bold');

% ------------------------------------------------------------
% 12. Final ROI Highlight
% ------------------------------------------------------------

nexttile;

imshow(highlightedImage);

title( ...
    '12. Final ROI Highlighting', ...
    'FontSize', 12, ...
    'FontWeight', 'bold');

% Overall pipeline title
sgtitle( ...
    'CHEST X-RAY DIGITAL IMAGE PROCESSING PIPELINE', ...
    'FontSize', 18, ...
    'FontWeight', 'bold');

%% ============================================================
% 21. DISPLAY FINAL ROI MASK
% =============================================================

figure( ...
    'Name', ...
    'Selected ROI Mask', ...
    'NumberTitle', ...
    'off');

imshow(finalROI);

title( ...
    'Final Selected Potential High-Interest ROIs', ...
    'FontSize', 15, ...
    'FontWeight', 'bold');

%% ============================================================
% 22. ROI STATISTICS
% =============================================================

lungArea = nnz(lungMask);

roiArea = nnz(finalROI);

if lungArea > 0

    roiPercentage = ...
        (roiArea / lungArea) * 100;

else

    roiPercentage = 0;

end

%% ============================================================
% 23. DISPLAY NUMERICAL RESULTS
% =============================================================

fprintf('\n');
fprintf('============================================\n');
fprintf('       CHEST X-RAY ROI ANALYSIS\n');
fprintf('============================================\n');

fprintf( ...
    'Input Image        : %s\n', ...
    file);

fprintf( ...
    'Lung Area          : %d pixels\n', ...
    lungArea);

fprintf( ...
    'Selected ROI Area  : %d pixels\n', ...
    roiArea);

fprintf( ...
    'ROI Percentage     : %.2f %%\n', ...
    roiPercentage);

fprintf( ...
    'Selected ROIs      : %d\n', ...
    numberToKeep);

fprintf( ...
    'ROI Threshold      : %.4f\n', ...
    scoreThreshold);

fprintf('============================================\n');

%% ============================================================
% 24. DISPLAY ROI SCORE MAP
% =============================================================

figure( ...
    'Name', ...
    'Potential Abnormality ROI Score', ...
    'NumberTitle', ...
    'off');

imagesc(roiScore);

axis image;
axis off;

colorbar;

title( ...
    'Potential Abnormality / ROI Score', ...
    'FontSize', 15, ...
    'FontWeight', 'bold');