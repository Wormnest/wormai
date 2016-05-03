/**
 * This file is part of WormAI: An OpenTTD AI.
 * 
 * @file money.nut Class containing money related functions for WormAI.
 * Requirements: SuperLib.Money.
 *
 * License: GNU GPL - version 2 (see license.txt)
 * Author: Wormnest (Jacob Boerema)
 * Copyright: Jacob Boerema, 2013-2016.
 *
 */ 

/**
 * Define the WormMoney class containing money related functions.
 */
class WormMoney
{
	/** @name Money related functions */
    /// @{
	/**
	 * Check if we have enough money (via loan and on bank).
	 * @param money The amount of money we need.
	 * @return Boolean saying if we do or don't have enough money.
	 */
	static function HasMoney(money);

	/**
	 * Get the amount of money requested, loan if needed.
	 * @param money The amount of money we need.
	 * @return Boolean saying if we got the needed money or not.
	 */
	static function GetMoney(money);
	
	/**
	 * Compute the amount of money corrected for inflation.
	 * @param money The uncorrected amount of money.
	 * @return The inflation corrected amount of money.
	 * @note Adapted from SuperLib.Money.Inflate: Computes GetInflationRate only once.
	 */
	static function InflationCorrection(money);
	/// @}
}

function WormMoney::HasMoney(money)
{
	if (AICompany.GetBankBalance(AICompany.COMPANY_SELF) + (AICompany.GetMaxLoanAmount() - AICompany.GetLoanAmount()) >= money) return true;
	return false;
}

function WormMoney::GetMoney(money)
{
	if (!WormMoney.HasMoney(money)) {
		AILog.Info("We don't have enough money and we also can't loan enough for our needs (" + money + ").");
		AILog.Info("Bank balance: " + AICompany.GetBankBalance(AICompany.COMPANY_SELF) + 
			", max loan: " + AICompany.GetMaxLoanAmount() +
			", current loan: " + AICompany.GetLoanAmount());
		return false;
	}
	if (AICompany.GetBankBalance(AICompany.COMPANY_SELF) > money) return true;

	local loan = money - AICompany.GetBankBalance(AICompany.COMPANY_SELF) + AICompany.GetLoanInterval() + AICompany.GetLoanAmount();
	loan = loan - loan % AICompany.GetLoanInterval();
	AILog.Info("Need a loan to get " + money + ": " + loan);
	return AICompany.SetLoanAmount(loan);
}

function WormMoney::InflationCorrection(money)
{
	/* Using a local variable to compute inflation only once should be faster I think. */
	local inflation = _SuperLib_Money.GetInflationRate();
	return (money / 100) * inflation + (money % 100) * inflation / 100;
}
