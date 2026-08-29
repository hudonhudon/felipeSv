/* scripts made by Douwsky
for Iskall85's Vaulthunters */

// adding recipes

import crafttweaker.api.tag.MCTag;
import crafttweaker.api.recipe.Brewing;
import mods.initialinventory.InvHandler;
import mods.mekanism.recipe.Combining;
import mods.mekanism.api.ingredient.ItemStackIngredient;

craftingTable.addShaped("edge_light", <item:simplylight:edge_light>, [
    [<tag:items:forge:stone>, <item:minecraft:air>, <tag:items:forge:stone>],
    [<item:minecraft:glowstone_dust>, <item:minecraft:glowstone_dust>, <item:minecraft:glowstone_dust>],
    [<tag:items:forge:stone>, <item:minecraft:air>, <tag:items:forge:stone>]
]);