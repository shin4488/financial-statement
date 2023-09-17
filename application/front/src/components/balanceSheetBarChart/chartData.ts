interface Debit {
  currentAssetAmount: number;
  propertyPlantAndEquipmentAmount: number;
  intangibleAssetAmount: number;
  investmentAndOtherAssetAmount: number;
  currentAssetRatio: number;
  propertyPlantAndEquipmentRatio: number;
  intangibleAssetRatio: number;
  investmentAndOtherAssetRatio: number;
}

interface Credit {
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
  Debit,
  Credit,
  // 債務超過の場合のみ3つ目の棒グラフを表示
  MinusNetAsset?,
];

export type BalanceSheetAmountKeyLabel = {
  [K in (keyof Debit | keyof Credit | keyof MinusNetAsset) &
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
