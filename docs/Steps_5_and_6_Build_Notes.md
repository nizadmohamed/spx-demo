# Build notes: steps 5 and 6

For the developer building the SPX demo. Everything here is standard Salesforce functionality. Anything that is a demo shortcut is labelled as one.

---

## Step 5: capture a quote and price on an opportunity

**Native Sales Cloud only:** SPX has no CPQ or Revenue Cloud. Full mechanics are in section 6 of the handover pack. In short:

1. **Estimate on the opportunity:** the opportunity starts at $3,350,000 with no products. The rep adds one **opportunity product** at product-family level (Custom air handling unit, double wall × 8 at $418,750). Amount becomes the total of opportunity products.
2. **New Quote:** created from the opportunity. It includes the opportunity's products by default and uses the opportunity's price book (set automatically from brand and currency).
3. **Refine the quote:** on Quote Line Items, Add Products and Edit Products. Line Description is removed, and Sales Price is shown but not edited live (pre-staged values). Final lines:
   - double wall × 6 at $427,500
   - 100% outside air × 2 at $450,000
   - startup × 8 at $12,500
   - freight × 1 at $35,000

   Quote total **$3,600,000**.
4. **Start Sync:** the quote's line items replace the opportunity products, and Amount updates to $3,600,000. While syncing, line changes on either record update the other.

**Not in this step:** no PDF, no discount fields, no discount approval, no CPQ.

| Product (family level) | Family | List price (USD, per unit) | Basis |
|---|---|---|---|
| Custom air handling unit, double wall | Air handling | 450,000 | About 37,500 cfm × $12 per cfm (published AHU range $4–12 per cfm). Replace with Ingénia's budget prices |
| Custom air handling unit, 100% outside air | Air handling | 450,000 | As above |
| Modular air handling unit | Air handling | 280,000 | Estimate |
| Jobsite assembled air handling unit | Air handling | 410,000 | Estimate |
| Factory startup and commissioning | Services | 12,500 | Estimate |
| Freight and rigging | Services | 35,000 per shipment | Estimate |

**Reset:**
1. Stop Sync and delete the quote.
2. Delete the opportunity products.
3. Set Amount back to $3,350,000.

## Step 6: onboard a new brand into a live org

**Storyline: Configure → Isolate → Validate → Transition.** It is tool-agnostic: the deployment mechanism is secondary to how the solution and cutover are designed. Full component lists, formulas and reset steps are in section 7 of `SPX_Developer_Handover_Pack.md` and on the "Step 6 components" sheet of the data workbook.

1. **Configure:**
   - Show the two record types and sales processes coexisting: Golden Template – Project Sale, and Cooling – Legacy.
   - Activate Chicago Fan: brand value, Lightning page (App Default), Brand Configuration Live, flow version 4, validation rule.
2. **Isolate:**
   - Show permission set **SPX Migration Bypass**, with custom permissions `SPX_Bypass_Validation_Rules` and `SPX_Bypass_Automation`, assigned only to the Migration User.
   - Assign SPX Chicago Fan to Kim.
3. **Validate:** Kim creates a golden-template opportunity (her profile has only that record type), completes the fan selection, moves to 3.0. The legacy Cooling regression test is voiced over.
4. **Transition:** show Setup › Bulk Data Load Jobs with the Migration User's loads (214 accounts, 38 opportunities); voice over the cutover options and the regression test.

**Not in this step:** Agentforce, Claude, change sets or deployment screens. **Don't demonstrate a failure.**
