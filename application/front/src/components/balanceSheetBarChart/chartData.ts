type Credit = {
  currentAsset: number;
  propertyPlantAndEquipment: number;
  intangibleAsset: number;
  investmentAndOtherAsset: number;
  currentAssetRatio: number;
  propertyPlantAndEquipmentRatio: number;
  intangibleAssetRatio: number;
  investmentAndOtherAssetRatio: number;
};

type Dept = {
  currentLiability: number;
  noncurrentLiability: number;
  netAsset?: number;
  currentLiabilityRatio: number;
  noncurrentLiabilityRatio: number;
  netAssetRatio?: number;
};

type MinusNetAsset = {
  blanckForInsolvency: number;
  netAsset: number;
  netAssetRatio: number;
};

export type BalanceSheetChart = [
  Credit,
  Dept,
  // 債務超過の場合のみ3つ目の棒グラフを表示
  MinusNetAsset?,
];

export type BalanceSheetAmountKeyLabel = {
  [K in (keyof Credit | keyof Dept | keyof MinusNetAsset) &
    (
      | 'currentAsset'
      | 'propertyPlantAndEquipment'
      | 'intangibleAsset'
      | 'investmentAndOtherAsset'
      | 'currentLiability'
      | 'noncurrentLiability'
      | 'netAsset'
    )]: string;
};
