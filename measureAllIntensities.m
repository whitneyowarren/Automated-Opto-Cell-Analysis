function i_out = measureAllIntensities(BW, IM, nClusters, icluster, closingRadius, erodeRadius, makeMovie, moviefile)
if nargin < 6 || isempty(erodeRadius)
    erodeRadius = 0;
end
if nargin < 7 || isempty(makeMovie)
    makeMovie = 0;
end
if nargin < 8 || isempty(moviefile)
    moviefile = 'tmp';
end

nCells = length(IM);
nT     = size(IM{1},3);
i_out  = nan*ones(nT, nCells);

warning off
for i = 1:nCells
    if makeMovie
%         cg = colormap('gray');
%         cg = round([cg(1:2:end,:); ones(128,1)*cg(end,:)]);
        writerObj = VideoWriter(sprintf('%s_%0.3d.avi', moviefile, i), 'Motion JPEG AVI');
        open(writerObj);
%         keyboard
%         writerObj.Colormap = cg;
%         writerObj = VideoWriter(sprintf('%s_%0.3d.avi', 'Motion JPEG AVI', i), 'colormap', cg);
    end
    for j = 1:nT
        I = IM{i}(:,:,j);
        B = BW{i}(:,:,j);
        if erodeRadius
            B = imerode(B, strel('disk', erodeRadius));
        end
        [i_out(j,i) IMout] = measureIntensity(B, I, nClusters, icluster, closingRadius);
        if isempty(IMout)
            IMout = false(size(I));
        end
        if makeMovie
            IMmovie = I+30*uint8(IMout);
%             F = getframe(IMmovie);
%             cg = colormap('jet');
%             F.Colormap = cg;
            writeVideo(writerObj,IMmovie);
        end
    end
    fprintf('.')
    if makeMovie
        close(writerObj);
    end
%     pause
end
fprintf('\n')
warning on
