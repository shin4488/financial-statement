interface Credit {
  currentAssetAmount: number;
  propertyPlantAndEquipmentAmount: number;
  intangibleAssetAmount: number;
  investmentAndOtherAssetAmount: number;
  currentAssetRatio: number;
  propertyPlantAndEquipmentRatio: number;
  intangibleAssetRatio: number;
  investmentAndOtherAssetRatio: number;
}

interface Dept {
  currentLiabilityAmount: number;
  noncurrentLiabilityAmount: number;
  netAssetAmount?: number;
  currentLiabilityRatio: number;
  noncurrentLiabilityRatio: number;
  netAssetRatio?: number;
}

interface MinusNetAsset {
  blanckForInsolvencyAmount: number;
  netAssetAmount: number;
  netAssetRatio: number;
}

export type BalanceSheetChart = [
  Credit,
  Dept,
  // 債務超過の場合のみ3つ目の棒グラフを表示
  MinusNetAsset?,
];

export type BalanceSheetAmountKeyLabel = {
  [K in (keyof Credit | keyof Dept | keyof MinusNetAsset) &
    (
      | 'currentAssetAmount'
      | 'propertyPlantAndEquipmentAmount'
      | 'intangibleAssetAmount'
      | 'investmentAndOtherAssetAmount'
      | 'currentLiabilityAmount'
      | 'noncurrentLiabilityAmount'
      | 'netAssetAmount'
    )]: string;
};
