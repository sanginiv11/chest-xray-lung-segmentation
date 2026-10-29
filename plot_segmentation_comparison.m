% Segmentation Performance Comparison
% Basic vs Improved Method

% Results from Montgomery dataset (138 images)
methods = {'Basic', 'Improved'};

dice = [0.2678, 0.6690];
iou  = [0.2162, 0.5441];

% Create comparison graph
figure('Name','Segmentation Performance Comparison');

values = [dice; iou]';

bar(values);

% Labels
set(gca, 'XTickLabel', methods);
xlabel('Segmentation Method');
ylabel('Score');
title('Basic vs Improved Lung Segmentation');

% Legend
legend('Dice Score', 'IoU', 'Location', 'northwest');

% Y-axis range
ylim([0 1]);

% Grid
grid on;

% Display values on bars
for i = 1:size(values,1)
    for j = 1:size(values,2)
        text(i, values(i,j) + 0.02, ...
            sprintf('%.4f', values(i,j)), ...
            'HorizontalAlignment','center');
    end
end