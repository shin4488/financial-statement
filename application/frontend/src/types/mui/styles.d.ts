import { Palette } from '@mui/material';

// createThemeのpaletteにアプリ独自色（positive/negative）を渡せるようにする型拡張。
// tsconfigのincludeで自動的に読み込まれるためimportは不要
declare module '@mui/material/styles' {
  interface PaletteOptions {
    positive: Palette['primary'];
    negative: Palette['primary'];
  }
}
