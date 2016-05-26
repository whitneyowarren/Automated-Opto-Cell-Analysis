%% EDIT THIS SECTION

% Number of timepoints
nT = 120;

% Intensity threshold for nuclei in irFP channel
irFP_threshold = 45; 

pathname  = '/Users/wowarren/Desktop/Toettcher_Lab/5-20-16';
BFP_file  = 'PDGF-Aniso_xy2_BFP-Erk.tif';
% YFP_file  = '';
RFP_file  = 'PDGF-Aniso_xy2_Pif-SOS-H2B-iRFP.tif';
irFP_file = 'PDGF-Aniso_xy2_Pif-SOS-H2B-iRFP.tif';
irFP_file_filtered = 'PDGF-Aniso_xy2_Pif-SOS-H2B-iRFPf.tif';


% END EDITS

%% Initialize
tic
addpath ('utils');
addpath ('/Users/wowarren/Documents/MATLAB/ANALYSIS/utils');

%% Get irFP band pass image
disp('Loading irFP images...')
IM_irFP = loadData(pathname, irFP_file_filtered, 1:nT, 0);
BW_nuclei = IM_irFP > irFP_threshold;
toc

% Don't keep this open
clear IM_irFP;

%% Now segment nuclei (total runtime = a few mins)
disp('Segmenting individual nuclei...')
warning off

for i = 1:nT
    BW_nuclei(:,:,i) = curateNuclei2(BW_nuclei(:,:,i));
    fprintf('.')
end
fprintf('\n')
warning on
toc

%% Track nuclei between all frames (total runtime = a few mins)
disp('Tracking nuclei...')
[L_track r_track c_track] = getTrackedNuclei(BW_nuclei);
nCells = size(r_track,2);
clear BW_nuclei

%% Make movies of each tracked cell in each color you care about!
IM_BFP  = loadData(pathname, BFP_file, 1:nT, 0);
%IM_YFP  = loadData(pathname, YFP_file, 1:nT, 0);
IM_RFP  = loadData(pathname, RFP_file, 1:nT, 0);

BFP_cell    = getCellBoxes(r_track, c_track, IM_BFP);
%YFP_cell    = getCellBoxes(r_track, c_track, IM_YFP);
RFP_cell    = getCellBoxes(r_track, c_track, IM_RFP);

clear IM_BFP IM_RFP % 

% A little more complicated for the tracked nuclei.
BW_nuc_cell = getCellBoxes(r_track, c_track, L_track);

for i = 1:nCells
    BW_nuc_cell{i} = BW_nuc_cell{i} == i;
end

%% Get rid of empty cells!
numSkipped = 0;
i_skipped = [];
for i = 1:nCells
    if ~any(BW_nuc_cell{i}(:))
        numSkipped = numSkipped + 1;
        i_skipped = [i_skipped i];
    end
end

i_keep = setdiff(1:nCells, i_skipped);

BW_nuc_cell = BW_nuc_cell(i_keep);
BFP_cell = BFP_cell(i_keep);
% YFP_cell = YFP_cell(i_keep);
RFP_cell = RFP_cell(i_keep);

nCells = length(i_keep);

% Get cytoplasmic regions!
disp('Finding cytoplasmic regions...')

warning off
for i = 1:nCells
    BFP_cell_smooth = filterImage(BFP_cell{i},2);
    RFP_cell_smooth = filterImage(RFP_cell{i},2);
    BW_cyt_cell_k(i,:) = getCytoplasmicRegionCandidates(BFP_cell_smooth, ...
                                                        RFP_cell_smooth, ...
                                                        BW_nuc_cell{i});
    fprintf('.')
end
fprintf('\n')
warning on
toc

%% Make a matrix of zeros for which clusters have cytoplasmic regions
isgood = zeros(nCells,4);

%% Check by eye which cytoplasmic cluster is good
disp('Are these cytoplasmic regions? (ENTER if no, ''y'' if yes)')

for i = 1:nCells
    for k = 1:4
        for j = 1:2:nT
            imshow(BFP_cell{i}(:,:,j) + 50*uint8(BW_cyt_cell_k{i,k}(:,:,j)), [], 'InitialMagnification',200)
            title(sprintf('cell %d cluster %d time %d', i, k, j))
            drawnow
        end
        tmp = input('> ', 's');
        if ~isempty(tmp)
            isgood(i,k) = 1;
        else
            isgood(i,k) = 0;
        end
    end
end

%% 
BW_cyt_cell = getGoodCytoplasmicRegions(BW_cyt_cell_k, isgood);

%% MEASURE BACKGROUND

disp('Measuring background BFP')

IM_BFP  = loadData(pathname, BFP_file, 1:nT, 0);
for i = 1:nT
    i_bkgd_bfp(i) = getBackgroundIntensity(IM_BFP(:,:,i)); 
    drawnow
end
i_bkgd_bfp = i_bkgd_bfp(:);
clear IM_BFP

%% MEASURE BACKGROUND

% disp('Measuring background YFP')

% IM_YFP  = loadData(pathname, YFP_file, 1:nT, 0);
% for i = 1:nT
%    i_bkgd_yfp(i) = getBackgroundIntensity(IM_YFP(:,:,i)); 
%    drawnow
% end
% i_bkgd_yfp = i_bkgd_yfp(:);
% clear IM_YFP

%% MEASURE BFP

disp('Measuring intensities')

i_nuc_bfp = measureAllIntensities(BW_nuc_cell, BFP_cell, 2, 2, 2, 5,  1, 'bfp_nuc');
i_cyt_bfp = measureAllIntensities(BW_cyt_cell, BFP_cell, 2, 2, 5, [], 1, 'bfp_cyt');
% i_cyt_yfp = measureAllIntensities(BW_cyt_cell, YFP_cell, 2, 2, 5, [], 1, 'yfp_cyt');

analyzed_cells = find(any(~isnan(i_cyt_bfp)));

%%

save ('images.mat', 'BW_nuc_cell', 'BW_cyt_cell', 'L_track', 'r_track', 'c_track', 'BFP_cell', 'RFP_cell') % , 'YFP_cell'
save ('analysis.mat', 'i_nuc_bfp', 'i_cyt_bfp', 'i_bkgd_bfp', 'analyzed_cells', 'nCells', 'nT') % , 'i_cyt_yfp', 'i_bkgd_yfp'

%% Plot each cell over time
for i = 15:nCells
    ns = i_nuc_bfp(:,i) - i_bkgd_bfp;
    cs = i_cyt_bfp(:,i) - i_bkgd_bfp;
    % ys = i_cyt_yfp(:,i) - i_bkgd_yfp;
    plot(1:nT, bfilt2n(ns')', ...
         1:nT, bfilt2n(cs')') ...
        %  1:nT, bfilt2n(ys')')
%       Above smooths out curves
%    plot(1:nT, (ns')', ...
%         1:nT, (cs')', ...
%         1:nT, (ys')')
%       No smoothing
    legend({'nuc' 'cyt' 'SOS'})
    pause
end

%% Some nice plots
nuc_values = ((i_nuc_bfp(:,analyzed_cells)-i_bkgd_bfp*ones(1,length(analyzed_cells)))');
tmp = sort(nuc_values, 2);
mm  = nanmean(tmp(:,1:10),2);
MM  = nanmean(tmp(:,end-9:end),2);
nuc_values = (nuc_values-mm*ones(1,nT))./(MM*ones(1,nT)-mm*ones(1,nT));

figure(1)
set(gcf, 'position', [9 205 629 618])
subplot(2,1,1)
imagesc(bfilt2n(nuc_values))
colormap redbluecmap
xlabel('time (frames)')
ylabel('cell #')

subplot(2,1,2)
plot(bfilt2n(nuc_values)')
set(gca, 'ylim', [-0.5 1.5])
xlabel('time (frames)')
ylabel('Nuclear Erk dynamics')

%% Some nice plots
cyt_values = ((i_cyt_bfp(:,analyzed_cells)-i_bkgd_bfp*ones(1,length(analyzed_cells)))');
tmp = sort(cyt_values, 2);
mm  = nanmean(tmp(:,1:10),2);
MM  = nanmean(tmp(:,end-9:end),2);
cyt_values = (cyt_values-mm*ones(1,nT))./(MM*ones(1,nT)-mm*ones(1,nT));

figure(2)
set(gcf, 'position', [9 205 629 618])
subplot(2,1,1)
imagesc(bfilt2n(cyt_values))
colormap redbluecmap
xlabel('time (frames)')
ylabel('cell #')

subplot(2,1,2)
plot(bfilt2n(cyt_values)')
set(gca, 'ylim', [-0.5 1.5])
xlabel('time (frames)')
ylabel('Cytoplasmic Erk dynamics')
