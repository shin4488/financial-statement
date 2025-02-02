export interface WaterFlowBarChartElement {
  name: string;
  value: number;
  previousSum: number;
}

export interface WaterFlowBarChartProps {
  data: WaterFlowBarChartElement[];
  positiveColor: string;
  negativeColor: string;
  unit: string;
}
