function IM = filterImage(IM, blur)

h = fspecial('average', blur*[1 1]);

nT = size(IM, 3);

for i = 1:nT
    IM(:,:,i)  = imfilter(IM(:,:,i), h);
    fprintf('.')
end
fprintf('\n')

