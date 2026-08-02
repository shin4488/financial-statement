/* eslint-disable */
import { TypedDocumentNode as DocumentNode } from '@graphql-typed-document-node/core';
export type Maybe<T> = T | null;
export type InputMaybe<T> = Maybe<T>;
export type Exact<T extends { [key: string]: unknown }> = { [K in keyof T]: T[K] };
export type MakeOptional<T, K extends keyof T> = Omit<T, K> & { [SubKey in K]?: Maybe<T[SubKey]> };
export type MakeMaybe<T, K extends keyof T> = Omit<T, K> & { [SubKey in K]: Maybe<T[SubKey]> };
export type MakeEmpty<T extends { [key: string]: unknown }, K extends keyof T> = { [_ in K]?: never };
export type Incremental<T> = T | { [P in keyof T]?: P extends ' $fragmentName' | '__typename' ? T[P] : never };
/** All built-in and custom scalars, mapped to their actual values */
export type Scalars = {
  ID: { input: string; output: string; }
  String: { input: string; output: string; }
  Boolean: { input: boolean; output: boolean; }
  Int: { input: number; output: number; }
  Float: { input: number; output: number; }
  /** Represents non-fractional signed whole numeric values. Since the value may exceed the size of a 32-bit integer, it's encoded as a string. */
  BigInt: { input: any; output: any; }
  /** 円単位の金額。Int32の範囲を超え得るがJSON上は数値のまま返す */
  Money: { input: number; output: number; }
};

export type BalanceSheet = {
  __typename?: 'BalanceSheet';
  amount?: Maybe<BalanceSheetAmount>;
  ratio?: Maybe<BalanceSheetRatio>;
};

export type BalanceSheetAmount = {
  __typename?: 'BalanceSheetAmount';
  currentAsset?: Maybe<Scalars['BigInt']['output']>;
  currentLiability?: Maybe<Scalars['BigInt']['output']>;
  intangibleAsset?: Maybe<Scalars['BigInt']['output']>;
  investmentAndOtherAsset?: Maybe<Scalars['BigInt']['output']>;
  netAsset?: Maybe<Scalars['BigInt']['output']>;
  noncurrentLiability?: Maybe<Scalars['BigInt']['output']>;
  propertyPlantAndEquipment?: Maybe<Scalars['BigInt']['output']>;
};

export type BalanceSheetRatio = {
  __typename?: 'BalanceSheetRatio';
  currentAsset?: Maybe<Scalars['Float']['output']>;
  currentLiability?: Maybe<Scalars['Float']['output']>;
  intangibleAsset?: Maybe<Scalars['Float']['output']>;
  investmentAndOtherAsset?: Maybe<Scalars['Float']['output']>;
  netAsset?: Maybe<Scalars['Float']['output']>;
  noncurrentLiability?: Maybe<Scalars['Float']['output']>;
  propertyPlantAndEquipment?: Maybe<Scalars['Float']['output']>;
};

export type CashFlow = {
  __typename?: 'CashFlow';
  endingCash?: Maybe<Scalars['BigInt']['output']>;
  financingActivitiesCashFlow?: Maybe<Scalars['BigInt']['output']>;
  investingActivitiesCashFlow?: Maybe<Scalars['BigInt']['output']>;
  operatingActivitiesCashFlow?: Maybe<Scalars['BigInt']['output']>;
  startingCash?: Maybe<Scalars['BigInt']['output']>;
};

export enum CashFlowSign {
  Negative = 'NEGATIVE',
  Positive = 'POSITIVE'
}

export type CompanyFinancialStatement = {
  __typename?: 'CompanyFinancialStatement';
  balanceSheet?: Maybe<BalanceSheet>;
  cashFlow?: Maybe<CashFlow>;
  companyJapaneseName?: Maybe<Scalars['String']['output']>;
  consolidatedInductoryCode?: Maybe<Scalars['String']['output']>;
  filingDate?: Maybe<Scalars['String']['output']>;
  fiscalYearEndDate?: Maybe<Scalars['String']['output']>;
  fiscalYearStartDate?: Maybe<Scalars['String']['output']>;
  hasConsolidatedFinancialStatement?: Maybe<Scalars['Boolean']['output']>;
  id: Scalars['ID']['output'];
  nonConsolidatedInductoryCode?: Maybe<Scalars['String']['output']>;
  profitLoss?: Maybe<ProfitLoss>;
  stockCode?: Maybe<Scalars['String']['output']>;
};

export type FinancialReport = {
  __typename?: 'FinancialReport';
  /** 表示中の財務諸表の基準（バッジ表示用。描画分岐に使わないこと） */
  accountingStandard: Scalars['String']['output'];
  balanceSheet: StackChart;
  cashFlow: WaterfallChart;
  companyName?: Maybe<Scalars['String']['output']>;
  /** "consolidated" | "non_consolidated" */
  consolidationType: Scalars['String']['output'];
  filingDate?: Maybe<Scalars['String']['output']>;
  fiscalYearEndDate: Scalars['String']['output'];
  fiscalYearStartDate: Scalars['String']['output'];
  id: Scalars['ID']['output'];
  presentationFormat: Scalars['String']['output'];
  profitLoss: StackChart;
  /** 4桁（EDINETの5桁から末尾0を落として返す） */
  stockCode?: Maybe<Scalars['String']['output']>;
};

export type Mutation = {
  __typename?: 'Mutation';
  sandboxTest?: Maybe<SandboxTestPayload>;
};


export type MutationSandboxTestArgs = {
  input: SandboxTestInput;
};

export enum NumberSign {
  Negative = 'NEGATIVE',
  Positive = 'POSITIVE'
}

export type ProfitLoss = {
  __typename?: 'ProfitLoss';
  amount?: Maybe<ProfitLossAmount>;
  ratio?: Maybe<ProfitLossRatio>;
};

export type ProfitLossAmount = {
  __typename?: 'ProfitLossAmount';
  netSales?: Maybe<Scalars['BigInt']['output']>;
  operatingIncome?: Maybe<Scalars['BigInt']['output']>;
  originalCost?: Maybe<Scalars['BigInt']['output']>;
  sellingGeneralExpense?: Maybe<Scalars['BigInt']['output']>;
};

export type ProfitLossRatio = {
  __typename?: 'ProfitLossRatio';
  netSales?: Maybe<Scalars['Float']['output']>;
  operatingIncome?: Maybe<Scalars['Float']['output']>;
  originalCost?: Maybe<Scalars['Float']['output']>;
  sellingGeneralExpense?: Maybe<Scalars['Float']['output']>;
};

export type Query = {
  __typename?: 'Query';
  /** Find Company Financial Statement by limit */
  companyFinancialStatements?: Maybe<Array<CompanyFinancialStatement>>;
  /** 有報の財務3表チャート一覧（提出日降順） */
  financialReports: Array<FinancialReport>;
};


export type QueryCompanyFinancialStatementsArgs = {
  financingActivitiesCashFlowSign?: InputMaybe<NumberSign>;
  investingActivitiesCashFlowSign?: InputMaybe<NumberSign>;
  limit: Scalars['Int']['input'];
  offset: Scalars['Int']['input'];
  operatingActivitiesCashFlowSign?: InputMaybe<NumberSign>;
  stockCodes?: InputMaybe<Array<Scalars['String']['input']>>;
};


export type QueryFinancialReportsArgs = {
  financingCfSign?: InputMaybe<CashFlowSign>;
  investingCfSign?: InputMaybe<CashFlowSign>;
  limit: Scalars['Int']['input'];
  offset: Scalars['Int']['input'];
  operatingCfSign?: InputMaybe<CashFlowSign>;
  stockCodes?: InputMaybe<Array<Scalars['String']['input']>>;
};

export type SandboxBookmark = {
  documentId: Scalars['String']['input'];
  userId: Scalars['String']['input'];
};

/** this is Sandbox type to practice GraphQL */
export type SandboxTest = {
  __typename?: 'SandboxTest';
  id: Scalars['ID']['output'];
  rating?: Maybe<Scalars['Int']['output']>;
  title?: Maybe<Scalars['String']['output']>;
};

/** Autogenerated input type of SandboxTest */
export type SandboxTestInput = {
  attributes: SandboxBookmark;
  /** A unique identifier for the client performing the mutation. */
  clientMutationId?: InputMaybe<Scalars['String']['input']>;
};

/** Autogenerated return type of SandboxTest. */
export type SandboxTestPayload = {
  __typename?: 'SandboxTestPayload';
  /** A unique identifier for the client performing the mutation. */
  clientMutationId?: Maybe<Scalars['String']['output']>;
  sandboxTestaa: SandboxTest;
};

export type Segment = {
  __typename?: 'Segment';
  /** 描画高さ（常に0以上） */
  amount: Scalars['Money']['output'];
  colorRole: Scalars['String']['output'];
  key: Scalars['String']['output'];
  label: Scalars['String']['output'];
  /** %（spacer等の非表示セグメントはnull） */
  ratio?: Maybe<Scalars['Float']['output']>;
  /** 実値（ツールチップ用。損失は負） */
  signedAmount: Scalars['Money']['output'];
};

export type StackBar = {
  __typename?: 'StackBar';
  label: Scalars['String']['output'];
  segments: Array<Segment>;
};

export type StackChart = {
  __typename?: 'StackChart';
  bars: Array<StackBar>;
  /** renderable=false のとき表示する説明文 */
  note?: Maybe<Scalars['String']['output']>;
  renderable: Scalars['Boolean']['output'];
};

export type WaterfallChart = {
  __typename?: 'WaterfallChart';
  note?: Maybe<Scalars['String']['output']>;
  renderable: Scalars['Boolean']['output'];
  steps: Array<WaterfallStep>;
};

export type WaterfallStep = {
  __typename?: 'WaterfallStep';
  /** 符号付き（増減の向きが情報のため） */
  amount: Scalars['Money']['output'];
  key: Scalars['String']['output'];
  /** "balance"（残高・0起点） | "flow"（増減・累積位置から描く） */
  kind: Scalars['String']['output'];
  label: Scalars['String']['output'];
};

export type FinancialReportsQueryVariables = Exact<{
  limit: Scalars['Int']['input'];
  offset: Scalars['Int']['input'];
  stockCodes?: InputMaybe<Array<Scalars['String']['input']> | Scalars['String']['input']>;
  operatingCfSign?: InputMaybe<CashFlowSign>;
  investingCfSign?: InputMaybe<CashFlowSign>;
  financingCfSign?: InputMaybe<CashFlowSign>;
}>;


export type FinancialReportsQuery = { __typename?: 'Query', financialReports: Array<{ __typename?: 'FinancialReport', id: string, stockCode?: string | null, companyName?: string | null, fiscalYearStartDate: string, fiscalYearEndDate: string, accountingStandard: string, consolidationType: string, balanceSheet: { __typename?: 'StackChart', renderable: boolean, note?: string | null, bars: Array<{ __typename?: 'StackBar', label: string, segments: Array<{ __typename?: 'Segment', key: string, label: string, amount: number, signedAmount: number, ratio?: number | null, colorRole: string }> }> }, profitLoss: { __typename?: 'StackChart', renderable: boolean, note?: string | null, bars: Array<{ __typename?: 'StackBar', label: string, segments: Array<{ __typename?: 'Segment', key: string, label: string, amount: number, signedAmount: number, ratio?: number | null, colorRole: string }> }> }, cashFlow: { __typename?: 'WaterfallChart', renderable: boolean, note?: string | null, steps: Array<{ __typename?: 'WaterfallStep', key: string, label: string, amount: number, kind: string }> } }> };


export const FinancialReportsDocument = {"kind":"Document","definitions":[{"kind":"OperationDefinition","operation":"query","name":{"kind":"Name","value":"FinancialReports"},"variableDefinitions":[{"kind":"VariableDefinition","variable":{"kind":"Variable","name":{"kind":"Name","value":"limit"}},"type":{"kind":"NonNullType","type":{"kind":"NamedType","name":{"kind":"Name","value":"Int"}}}},{"kind":"VariableDefinition","variable":{"kind":"Variable","name":{"kind":"Name","value":"offset"}},"type":{"kind":"NonNullType","type":{"kind":"NamedType","name":{"kind":"Name","value":"Int"}}}},{"kind":"VariableDefinition","variable":{"kind":"Variable","name":{"kind":"Name","value":"stockCodes"}},"type":{"kind":"ListType","type":{"kind":"NonNullType","type":{"kind":"NamedType","name":{"kind":"Name","value":"String"}}}}},{"kind":"VariableDefinition","variable":{"kind":"Variable","name":{"kind":"Name","value":"operatingCfSign"}},"type":{"kind":"NamedType","name":{"kind":"Name","value":"CashFlowSign"}}},{"kind":"VariableDefinition","variable":{"kind":"Variable","name":{"kind":"Name","value":"investingCfSign"}},"type":{"kind":"NamedType","name":{"kind":"Name","value":"CashFlowSign"}}},{"kind":"VariableDefinition","variable":{"kind":"Variable","name":{"kind":"Name","value":"financingCfSign"}},"type":{"kind":"NamedType","name":{"kind":"Name","value":"CashFlowSign"}}}],"selectionSet":{"kind":"SelectionSet","selections":[{"kind":"Field","name":{"kind":"Name","value":"financialReports"},"arguments":[{"kind":"Argument","name":{"kind":"Name","value":"limit"},"value":{"kind":"Variable","name":{"kind":"Name","value":"limit"}}},{"kind":"Argument","name":{"kind":"Name","value":"offset"},"value":{"kind":"Variable","name":{"kind":"Name","value":"offset"}}},{"kind":"Argument","name":{"kind":"Name","value":"stockCodes"},"value":{"kind":"Variable","name":{"kind":"Name","value":"stockCodes"}}},{"kind":"Argument","name":{"kind":"Name","value":"operatingCfSign"},"value":{"kind":"Variable","name":{"kind":"Name","value":"operatingCfSign"}}},{"kind":"Argument","name":{"kind":"Name","value":"investingCfSign"},"value":{"kind":"Variable","name":{"kind":"Name","value":"investingCfSign"}}},{"kind":"Argument","name":{"kind":"Name","value":"financingCfSign"},"value":{"kind":"Variable","name":{"kind":"Name","value":"financingCfSign"}}}],"selectionSet":{"kind":"SelectionSet","selections":[{"kind":"Field","name":{"kind":"Name","value":"id"}},{"kind":"Field","name":{"kind":"Name","value":"stockCode"}},{"kind":"Field","name":{"kind":"Name","value":"companyName"}},{"kind":"Field","name":{"kind":"Name","value":"fiscalYearStartDate"}},{"kind":"Field","name":{"kind":"Name","value":"fiscalYearEndDate"}},{"kind":"Field","name":{"kind":"Name","value":"accountingStandard"}},{"kind":"Field","name":{"kind":"Name","value":"consolidationType"}},{"kind":"Field","name":{"kind":"Name","value":"balanceSheet"},"selectionSet":{"kind":"SelectionSet","selections":[{"kind":"Field","name":{"kind":"Name","value":"renderable"}},{"kind":"Field","name":{"kind":"Name","value":"note"}},{"kind":"Field","name":{"kind":"Name","value":"bars"},"selectionSet":{"kind":"SelectionSet","selections":[{"kind":"Field","name":{"kind":"Name","value":"label"}},{"kind":"Field","name":{"kind":"Name","value":"segments"},"selectionSet":{"kind":"SelectionSet","selections":[{"kind":"Field","name":{"kind":"Name","value":"key"}},{"kind":"Field","name":{"kind":"Name","value":"label"}},{"kind":"Field","name":{"kind":"Name","value":"amount"}},{"kind":"Field","name":{"kind":"Name","value":"signedAmount"}},{"kind":"Field","name":{"kind":"Name","value":"ratio"}},{"kind":"Field","name":{"kind":"Name","value":"colorRole"}}]}}]}}]}},{"kind":"Field","name":{"kind":"Name","value":"profitLoss"},"selectionSet":{"kind":"SelectionSet","selections":[{"kind":"Field","name":{"kind":"Name","value":"renderable"}},{"kind":"Field","name":{"kind":"Name","value":"note"}},{"kind":"Field","name":{"kind":"Name","value":"bars"},"selectionSet":{"kind":"SelectionSet","selections":[{"kind":"Field","name":{"kind":"Name","value":"label"}},{"kind":"Field","name":{"kind":"Name","value":"segments"},"selectionSet":{"kind":"SelectionSet","selections":[{"kind":"Field","name":{"kind":"Name","value":"key"}},{"kind":"Field","name":{"kind":"Name","value":"label"}},{"kind":"Field","name":{"kind":"Name","value":"amount"}},{"kind":"Field","name":{"kind":"Name","value":"signedAmount"}},{"kind":"Field","name":{"kind":"Name","value":"ratio"}},{"kind":"Field","name":{"kind":"Name","value":"colorRole"}}]}}]}}]}},{"kind":"Field","name":{"kind":"Name","value":"cashFlow"},"selectionSet":{"kind":"SelectionSet","selections":[{"kind":"Field","name":{"kind":"Name","value":"renderable"}},{"kind":"Field","name":{"kind":"Name","value":"note"}},{"kind":"Field","name":{"kind":"Name","value":"steps"},"selectionSet":{"kind":"SelectionSet","selections":[{"kind":"Field","name":{"kind":"Name","value":"key"}},{"kind":"Field","name":{"kind":"Name","value":"label"}},{"kind":"Field","name":{"kind":"Name","value":"amount"}},{"kind":"Field","name":{"kind":"Name","value":"kind"}}]}}]}}]}}]}}]} as unknown as DocumentNode<FinancialReportsQuery, FinancialReportsQueryVariables>;