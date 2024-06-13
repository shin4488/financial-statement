import { CompanyFinancialStatement } from '@/__generated__/graphql';
import { FinancialStatement } from './state';
import StringUtil from '@/plugins/utils/stringUtil';
import { NumberUtil } from '@/plugins/utils/numberUtil';
import ApolloClientService from '@/plugins/apollo/service';
import {
  cashFlowTypeRequestMap,
  financialStatementOffsetUnit,
} from '@/constants/values';
import { FinancialStatementConditionParameter } from './parameter';

export default class FinancialStatementListStateService {
  private apolloService: ApolloClientService;

  constructor() {
    this.apolloService = new ApolloClientService();
  }

  query(offset: number, parameter: FinancialStatementConditionParameter) {
    const cashFlowRequest = cashFlowTypeRequestMap[parameter.cashFlowType];
    const result = this.apolloService
      .query(
        `
        query {
          companyFinancialStatements(` +
          `limit: ${financialStatementOffsetUnit}` +
          `, offset: ${offset}` +
          `, stockCodes: ${JSON.stringify(parameter.stockCodes)}` +
          `, operatingActivitiesCashFlowSign: ` +
          cashFlowRequest.operatingActivitiesCashFlowSign +
          `, investingActivitiesCashFlowSign: ` +
          cashFlowRequest.investingActivitiesCashFlowSign +
          `, financingActivitiesCashFlowSign: ` +
          cashFlowRequest.financingActivitiesCashFlowSign +
          `) {
            fiscalYearStartDate
            fiscalYearEndDate
            filingDate
            stockCode
            companyJapaneseName
            hasConsolidatedFinancialStatement
            consolidatedInductoryCode
            nonConsolidatedInductoryCode
            balanceSheet {
              amount {
                currentAsset
                propertyPlantAndEquipment
                intangibleAsset
                investmentAndOtherAsset
                currentLiability
                noncurrentLiability
                netAsset
              }
              ratio {
                currentAsset
                propertyPlantAndEquipment
                intangibleAsset
                investmentAndOtherAsset
                currentLiability
                noncurrentLiability
                netAsset
              }
            }
            profitLoss {
              amount {
                netSales
                originalCost
                sellingGeneralExpense
                operatingIncome
              }
              ratio {
                netSales
                originalCost
                sellingGeneralExpense
                operatingIncome
              }
            }
            cashFlow {
              startingCash
              operatingActivitiesCashFlow
              investingActivitiesCashFlow
              financingActivitiesCashFlow
              endingCash
            }
          }
        }
        `,
      )
      .then((result) => result);
    return result;
  }

  mapFinancialStatementFromResponseToState(
    financialStatementResponse: CompanyFinancialStatement,
  ): FinancialStatement {
    const balanceSheetAmount = financialStatementResponse.balanceSheet?.amount;
    const balanceSheetRatio = financialStatementResponse.balanceSheet?.ratio;
    const profitLossAmount = financialStatementResponse.profitLoss?.amount;
    const profitLossRatio = financialStatementResponse.profitLoss?.ratio;
    const cashFlow = financialStatementResponse.cashFlow;

    return {
      fiscalYearStartDate: StringUtil.toBlankIfEmpty(
        financialStatementResponse.fiscalYearStartDate,
      ),
      fiscalYearEndDate: StringUtil.toBlankIfEmpty(
        financialStatementResponse.fiscalYearEndDate,
      ),
      stockCode: StringUtil.toBlankIfEmpty(
        financialStatementResponse.stockCode,
      ).slice(0, -1),
      companyName: StringUtil.toBlankIfEmpty(
        financialStatementResponse.companyJapaneseName,
      ),
      hasConsolidatedFinancialStatement:
        financialStatementResponse.hasConsolidatedFinancialStatement || false,
      consolidatedInductoryCode: StringUtil.toBlankIfEmpty(
        financialStatementResponse.consolidatedInductoryCode,
      ),
      nonConsolidatedInductoryCode: StringUtil.toBlankIfEmpty(
        financialStatementResponse.nonConsolidatedInductoryCode,
      ),
      balanceSheet: {
        amount: {
          currentAsset: NumberUtil.toNumberOrDefault(
            balanceSheetAmount?.currentAsset,
          ),
          propertyPlantAndEquipment: NumberUtil.toNumberOrDefault(
            balanceSheetAmount?.propertyPlantAndEquipment,
          ),
          intangibleAsset: NumberUtil.toNumberOrDefault(
            balanceSheetAmount?.intangibleAsset,
          ),
          investmentAndOtherAsset: NumberUtil.toNumberOrDefault(
            balanceSheetAmount?.investmentAndOtherAsset,
          ),
          currentLiability: NumberUtil.toNumberOrDefault(
            balanceSheetAmount?.currentLiability,
          ),
          noncurrentLiability: NumberUtil.toNumberOrDefault(
            balanceSheetAmount?.noncurrentLiability,
          ),
          netAsset: NumberUtil.toNumberOrDefault(balanceSheetAmount?.netAsset),
        },
        ratio: {
          currentAsset: NumberUtil.toNumberOrDefault(
            balanceSheetRatio?.currentAsset,
          ),
          propertyPlantAndEquipment: NumberUtil.toNumberOrDefault(
            balanceSheetRatio?.propertyPlantAndEquipment,
          ),
          intangibleAsset: NumberUtil.toNumberOrDefault(
            balanceSheetRatio?.intangibleAsset,
          ),
          investmentAndOtherAsset: NumberUtil.toNumberOrDefault(
            balanceSheetRatio?.investmentAndOtherAsset,
          ),
          currentLiability: NumberUtil.toNumberOrDefault(
            balanceSheetRatio?.currentLiability,
          ),
          noncurrentLiability: NumberUtil.toNumberOrDefault(
            balanceSheetRatio?.noncurrentLiability,
          ),
          netAsset: NumberUtil.toNumberOrDefault(balanceSheetRatio?.netAsset),
        },
      },
      profitLoss: {
        amount: {
          netSales: NumberUtil.toNumberOrDefault(profitLossAmount?.netSales),
          originalCost: NumberUtil.toNumberOrDefault(
            profitLossAmount?.originalCost,
          ),
          sellingGeneralExpense: NumberUtil.toNumberOrDefault(
            profitLossAmount?.sellingGeneralExpense,
          ),
          operatingIncome: NumberUtil.toNumberOrDefault(
            profitLossAmount?.operatingIncome,
          ),
        },
        ratio: {
          netSales: NumberUtil.toNumberOrDefault(profitLossRatio?.netSales),
          originalCost: NumberUtil.toNumberOrDefault(
            profitLossRatio?.originalCost,
          ),
          sellingGeneralExpense: NumberUtil.toNumberOrDefault(
            profitLossRatio?.sellingGeneralExpense,
          ),
          operatingIncome: NumberUtil.toNumberOrDefault(
            profitLossRatio?.operatingIncome,
          ),
        },
      },
      cashFlow: {
        startingCash: NumberUtil.toNumberOrDefault(cashFlow?.startingCash),
        operatingActivitiesCashFlow: NumberUtil.toNumberOrDefault(
          cashFlow?.operatingActivitiesCashFlow,
        ),
        investingActivitiesCashFlow: NumberUtil.toNumberOrDefault(
          cashFlow?.investingActivitiesCashFlow,
        ),
        financingActivitiesCashFlow: NumberUtil.toNumberOrDefault(
          cashFlow?.financingActivitiesCashFlow,
        ),
        endingCash: NumberUtil.toNumberOrDefault(cashFlow?.endingCash),
      },
    };
  }
}
