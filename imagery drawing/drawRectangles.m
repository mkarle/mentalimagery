function [  ] = drawRectangles( E, I )
%DRAWRECTANGLES Summary of this function goes here
%   Detailed explanation goes here
s = regionprops(E, 'BoundingBox');
figure;
imagesc(ones(size(I)));
rectangles = reshape([s(:).BoundingBox]', [4,size(s,1)]);
rectangles = rectangles';
hold on;
for n = 1:size(rectangles,1)
    
    rectangle('Position' , rectangles(n,:));
end
hold off;
end

