clear all;
in = input('Enter a shape to use (circle or rectangle)\n','s');
if ~strcmp(in, 'circle') && ~strcmp(in,'rectangle')
    error('not a valid shape')
end
folder = dir(strcat(in,'/*.jpg'));
file = strcat(in,'/',folder(randi(numel(folder))).name);
I = imread(file);
G =  rgb2gray(I);
BW = ~im2bw(G);
E = edge(G, 'canny');
imshow(E)
if strcmp(in, 'circle')
    drawCircles(BW, I, E);
else
    drawRectangles(E, I);

end
