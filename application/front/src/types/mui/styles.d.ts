import { Palette } from '@mui/material';

declare module '@mui/material/styles' {
  interface PaletteOptions {
    positive: Palette['primary'];
    negative: Palette['primary'];
  }

  interface PaletteOptions {
    positive: Palette['primary'];
    negative: Palette['primary'];
  }

  interface CellPropsColorOverrides {
    positive: true;
    negative: true;
  }
}
