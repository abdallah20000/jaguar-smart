// Category photos (see /materials/credits for authors and licenses)
const IMG: Record<string, string> = {
  steel: "steel", cement: "cement", bricks: "bricks", sand: "sand", tiles: "tiles", paint: "paint",
  plumbing: "plumbing", electrical: "electrical", gypsum: "gypsum", insulation: "insulation",
};
export const categoryImage = (icon: string | null) => (icon && IMG[icon] ? `/materials/img/${IMG[icon]}.webp` : null);
