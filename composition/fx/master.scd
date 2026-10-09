(
var keys = [\lpf, \moogVcf, \delay, \comb, \reverb, \gverb, \tanh, \limiter];
if (ProxyChain.allSources[keys.first].isNil) {
	"proxy-chain.scd".loadRelative;
};
MainFX.clear;
~master = MainFX(Server.default, 2, keys);
~master.add(\moogVcf, 0.1);
//~master.add(\lpf, 0.45);
~master.add(\gverb, 0.03);
~master.add(\limiter, 1);
// ~master.gui
)