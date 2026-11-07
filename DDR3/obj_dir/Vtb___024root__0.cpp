// Verilated -*- C++ -*-
// DESCRIPTION: Verilator output: Design implementation internals
// See Vtb.h for the primary calling header

#include "Vtb__pch.h"

VlCoroutine Vtb___024root___eval_initial__TOP__Vtiming__0(Vtb___024root* vlSelf);
VlCoroutine Vtb___024root___eval_initial__TOP__Vtiming__1(Vtb___024root* vlSelf);

void Vtb___024root___eval_initial(Vtb___024root* vlSelf) {
    VL_DEBUG_IF(VL_DBG_MSGF("+    Vtb___024root___eval_initial\n"); );
    Vtb__Syms* const __restrict vlSymsp VL_ATTR_UNUSED = vlSelf->vlSymsp;
    auto& vlSelfRef = std::ref(*vlSelf).get();
    // Body
    Vtb___024root___eval_initial__TOP__Vtiming__0(vlSelf);
    Vtb___024root___eval_initial__TOP__Vtiming__1(vlSelf);
}

VlCoroutine Vtb___024root___eval_initial__TOP__Vtiming__0(Vtb___024root* vlSelf) {
    VL_DEBUG_IF(VL_DBG_MSGF("+    Vtb___024root___eval_initial__TOP__Vtiming__0\n"); );
    Vtb__Syms* const __restrict vlSymsp VL_ATTR_UNUSED = vlSelf->vlSymsp;
    auto& vlSelfRef = std::ref(*vlSelf).get();
    // Body
    vlSelfRef.tb__DOT__rst_n = 0U;
    co_await vlSelfRef.__VdlySched.delay(0x00000000000186a0ULL, 
                                         nullptr, "tb.v", 
                                         30);
    vlSelfRef.tb__DOT__rst_n = 1U;
    co_await vlSelfRef.__VdlySched.delay(0x0000000003938700ULL, 
                                         nullptr, "tb.v", 
                                         32);
    VL_WRITEF_NX("state_led=%b\n",1, '#',6,vlSelfRef.tb__DOT__dut__DOT__init_done);
    VL_FINISH_MT("tb.v", 34, "");
    co_return;
}

VlCoroutine Vtb___024root___eval_initial__TOP__Vtiming__1(Vtb___024root* vlSelf) {
    VL_DEBUG_IF(VL_DBG_MSGF("+    Vtb___024root___eval_initial__TOP__Vtiming__1\n"); );
    Vtb__Syms* const __restrict vlSymsp VL_ATTR_UNUSED = vlSelf->vlSymsp;
    auto& vlSelfRef = std::ref(*vlSelf).get();
    // Body
    while (VL_LIKELY(!vlSymsp->_vm_contextp__->gotFinish())) {
        co_await vlSelfRef.__VdlySched.delay(0x0000000000002710ULL, 
                                             nullptr, 
                                             "tb.v", 
                                             26);
        vlSelfRef.tb__DOT__clk = (1U & (~ (IData)(vlSelfRef.tb__DOT__clk)));
    }
    co_return;
}

bool Vtb___024root___trigger_anySet__act(const VlUnpacked<QData/*63:0*/, 1> &in) {
    VL_DEBUG_IF(VL_DBG_MSGF("+    Vtb___024root___trigger_anySet__act\n"); );
    // Locals
    IData/*31:0*/ n;
    // Body
    n = 0U;
    do {
        if (in[n]) {
            return (1U);
        }
        n = ((IData)(1U) + n);
    } while ((1U > n));
    return (0U);
}

void Vtb___024root___trigger_orInto__act_vec_vec(VlUnpacked<QData/*63:0*/, 1> &out, const VlUnpacked<QData/*63:0*/, 1> &in) {
    VL_DEBUG_IF(VL_DBG_MSGF("+    Vtb___024root___trigger_orInto__act_vec_vec\n"); );
    // Locals
    IData/*31:0*/ n;
    // Body
    n = 0U;
    do {
        out[n] = (out[n] | in[n]);
        n = ((IData)(1U) + n);
    } while ((0U >= n));
}

#ifdef VL_DEBUG
VL_ATTR_COLD void Vtb___024root___dump_triggers__act(const VlUnpacked<QData/*63:0*/, 1> &triggers, const std::string &tag);
#endif  // VL_DEBUG

bool Vtb___024root___eval_phase__act(Vtb___024root* vlSelf) {
    VL_DEBUG_IF(VL_DBG_MSGF("+    Vtb___024root___eval_phase__act\n"); );
    Vtb__Syms* const __restrict vlSymsp VL_ATTR_UNUSED = vlSelf->vlSymsp;
    auto& vlSelfRef = std::ref(*vlSelf).get();
    // Locals
    CData/*0:0*/ __VactExecute;
    // Body
    {
        // Inlined CFunc: _eval_triggers_vec__act
        vlSelfRef.__VactTriggered[0U] = (QData)((IData)(
                                                        ((vlSelfRef.__VdlySched.awaitingCurrentTime() 
                                                          << 2U) 
                                                         | ((((~ (IData)(vlSelfRef.tb__DOT__rst_n)) 
                                                              & (IData)(vlSelfRef.__Vtrigprevexpr___TOP__tb__DOT__rst_n__0)) 
                                                             << 1U) 
                                                            | ((IData)(vlSelfRef.tb__DOT__clk) 
                                                               & (~ (IData)(vlSelfRef.__Vtrigprevexpr___TOP__tb__DOT__clk__0)))))));
        vlSelfRef.__Vtrigprevexpr___TOP__tb__DOT__clk__0 
            = vlSelfRef.tb__DOT__clk;
        vlSelfRef.__Vtrigprevexpr___TOP__tb__DOT__rst_n__0 
            = vlSelfRef.tb__DOT__rst_n;
    }
    Vtb___024root___trigger_orInto__act_vec_vec(vlSelfRef.__VactTriggered, vlSelfRef.__VactTriggeredAcc);
#ifdef VL_DEBUG
    if (VL_UNLIKELY(vlSymsp->_vm_contextp__->debug())) {
        Vtb___024root___dump_triggers__act(vlSelfRef.__VactTriggered, "act"s);
    }
#endif
    Vtb___024root___trigger_orInto__act_vec_vec(vlSelfRef.__VnbaTriggered, vlSelfRef.__VactTriggered);
    __VactExecute = Vtb___024root___trigger_anySet__act(vlSelfRef.__VactTriggered);
    if (__VactExecute) {
        vlSelfRef.__VactTriggeredAcc.fill(0ULL);
        {
            // Inlined CFunc: _timing_resume
            if ((4ULL & vlSelfRef.__VactTriggered[0U])) {
                vlSelfRef.__VdlySched.resume();
            }
        }
    }
    return (__VactExecute);
}

bool Vtb___024root___eval_phase__inact(Vtb___024root* vlSelf) {
    VL_DEBUG_IF(VL_DBG_MSGF("+    Vtb___024root___eval_phase__inact\n"); );
    Vtb__Syms* const __restrict vlSymsp VL_ATTR_UNUSED = vlSelf->vlSymsp;
    auto& vlSelfRef = std::ref(*vlSelf).get();
    // Locals
    CData/*0:0*/ __VinactExecute;
    // Body
    __VinactExecute = vlSelfRef.__VdlySched.awaitingZeroDelay();
    if (__VinactExecute) {
        VL_FATAL_MT("tb.v", 2, "", "ZERODLY: Design Verilated with '--no-sched-zero-delay', but #0 delay executed at runtime");
    }
    return (__VinactExecute);
}

void Vtb___024root___trigger_clear__act(VlUnpacked<QData/*63:0*/, 1> &out) {
    VL_DEBUG_IF(VL_DBG_MSGF("+    Vtb___024root___trigger_clear__act\n"); );
    // Locals
    IData/*31:0*/ n;
    // Body
    n = 0U;
    do {
        out[n] = 0ULL;
        n = ((IData)(1U) + n);
    } while ((1U > n));
}

bool Vtb___024root___eval_phase__nba(Vtb___024root* vlSelf) {
    VL_DEBUG_IF(VL_DBG_MSGF("+    Vtb___024root___eval_phase__nba\n"); );
    Vtb__Syms* const __restrict vlSymsp VL_ATTR_UNUSED = vlSelf->vlSymsp;
    auto& vlSelfRef = std::ref(*vlSelf).get();
    // Locals
    CData/*0:0*/ __VnbaExecute;
    // Body
    __VnbaExecute = Vtb___024root___trigger_anySet__act(vlSelfRef.__VnbaTriggered);
    if (__VnbaExecute) {
        {
            // Inlined CFunc: _eval_nba
            if ((3ULL & vlSelfRef.__VnbaTriggered[0U])) {
                {
                    // Inlined CFunc: _nba_sequent__TOP__0
                    SData/*14:0*/ __Vinline_0__eval_nba___Vinline_0__nba_sequent__TOP__0_tb__DOT__ddr_addr;
                    __Vinline_0__eval_nba___Vinline_0__nba_sequent__TOP__0_tb__DOT__ddr_addr = 0;
                    IData/*19:0*/ __Vinline_0__eval_nba___Vinline_0__nba_sequent__TOP__0___Vdly__tb__DOT__dut__DOT__u_ctrl__DOT__timer;
                    __Vinline_0__eval_nba___Vinline_0__nba_sequent__TOP__0___Vdly__tb__DOT__dut__DOT__u_ctrl__DOT__timer = 0;
                    CData/*3:0*/ __Vinline_0__eval_nba___Vinline_0__nba_sequent__TOP__0___Vdly__tb__DOT__dut__DOT__u_ctrl__DOT__state;
                    __Vinline_0__eval_nba___Vinline_0__nba_sequent__TOP__0___Vdly__tb__DOT__dut__DOT__u_ctrl__DOT__state = 0;
                    __Vinline_0__eval_nba___Vinline_0__nba_sequent__TOP__0___Vdly__tb__DOT__dut__DOT__u_ctrl__DOT__timer 
                        = vlSelfRef.tb__DOT__dut__DOT__u_ctrl__DOT__timer;
                    __Vinline_0__eval_nba___Vinline_0__nba_sequent__TOP__0___Vdly__tb__DOT__dut__DOT__u_ctrl__DOT__state 
                        = vlSelfRef.tb__DOT__dut__DOT__u_ctrl__DOT__state;
                    if (vlSelfRef.tb__DOT__rst_n) {
                        __Vinline_0__eval_nba___Vinline_0__nba_sequent__TOP__0___Vdly__tb__DOT__dut__DOT__u_ctrl__DOT__timer 
                            = (0x000fffffU & ((IData)(1U) 
                                              + vlSelfRef.tb__DOT__dut__DOT__u_ctrl__DOT__timer));
                        if ((8U & (IData)(vlSelfRef.tb__DOT__dut__DOT__u_ctrl__DOT__state))) {
                            __Vinline_0__eval_nba___Vinline_0__nba_sequent__TOP__0___Vdly__tb__DOT__dut__DOT__u_ctrl__DOT__state = 0U;
                        } else if ((4U & (IData)(vlSelfRef.tb__DOT__dut__DOT__u_ctrl__DOT__state))) {
                            if ((2U & (IData)(vlSelfRef.tb__DOT__dut__DOT__u_ctrl__DOT__state))) {
                                __Vinline_0__eval_nba___Vinline_0__nba_sequent__TOP__0___Vdly__tb__DOT__dut__DOT__u_ctrl__DOT__state = 0U;
                            } else if ((1U & (IData)(vlSelfRef.tb__DOT__dut__DOT__u_ctrl__DOT__state))) {
                                vlSelfRef.tb__DOT__dut__DOT__init_done = 1U;
                            } else if ((0x0000000aU 
                                        == vlSelfRef.tb__DOT__dut__DOT__u_ctrl__DOT__timer)) {
                                vlSelfRef.tb__DOT__dut__DOT__init_done = 1U;
                                __Vinline_0__eval_nba___Vinline_0__nba_sequent__TOP__0___Vdly__tb__DOT__dut__DOT__u_ctrl__DOT__state = 5U;
                                __Vinline_0__eval_nba___Vinline_0__nba_sequent__TOP__0___Vdly__tb__DOT__dut__DOT__u_ctrl__DOT__timer = 0U;
                            }
                        } else if ((2U & (IData)(vlSelfRef.tb__DOT__dut__DOT__u_ctrl__DOT__state))) {
                            if ((1U & (IData)(vlSelfRef.tb__DOT__dut__DOT__u_ctrl__DOT__state))) {
                                __Vinline_0__eval_nba___Vinline_0__nba_sequent__TOP__0_tb__DOT__ddr_addr 
                                    = (0x00000400U 
                                       | __Vinline_0__eval_nba___Vinline_0__nba_sequent__TOP__0_tb__DOT__ddr_addr);
                                if ((0x0000000aU == vlSelfRef.tb__DOT__dut__DOT__u_ctrl__DOT__timer)) {
                                    __Vinline_0__eval_nba___Vinline_0__nba_sequent__TOP__0___Vdly__tb__DOT__dut__DOT__u_ctrl__DOT__state = 4U;
                                    __Vinline_0__eval_nba___Vinline_0__nba_sequent__TOP__0___Vdly__tb__DOT__dut__DOT__u_ctrl__DOT__timer = 0U;
                                }
                            } else {
                                __Vinline_0__eval_nba___Vinline_0__nba_sequent__TOP__0_tb__DOT__ddr_addr = 0U;
                                if ((0x0000000aU == vlSelfRef.tb__DOT__dut__DOT__u_ctrl__DOT__timer)) {
                                    __Vinline_0__eval_nba___Vinline_0__nba_sequent__TOP__0___Vdly__tb__DOT__dut__DOT__u_ctrl__DOT__state = 3U;
                                    __Vinline_0__eval_nba___Vinline_0__nba_sequent__TOP__0___Vdly__tb__DOT__dut__DOT__u_ctrl__DOT__timer = 0U;
                                }
                            }
                        } else if ((1U & (IData)(vlSelfRef.tb__DOT__dut__DOT__u_ctrl__DOT__state))) {
                            if ((0x000001f4U == vlSelfRef.tb__DOT__dut__DOT__u_ctrl__DOT__timer)) {
                                __Vinline_0__eval_nba___Vinline_0__nba_sequent__TOP__0___Vdly__tb__DOT__dut__DOT__u_ctrl__DOT__state = 2U;
                                __Vinline_0__eval_nba___Vinline_0__nba_sequent__TOP__0___Vdly__tb__DOT__dut__DOT__u_ctrl__DOT__timer = 0U;
                            }
                        } else if ((0x000003e8U == vlSelfRef.tb__DOT__dut__DOT__u_ctrl__DOT__timer)) {
                            __Vinline_0__eval_nba___Vinline_0__nba_sequent__TOP__0___Vdly__tb__DOT__dut__DOT__u_ctrl__DOT__state = 1U;
                            __Vinline_0__eval_nba___Vinline_0__nba_sequent__TOP__0___Vdly__tb__DOT__dut__DOT__u_ctrl__DOT__timer = 0U;
                        }
                    } else {
                        __Vinline_0__eval_nba___Vinline_0__nba_sequent__TOP__0___Vdly__tb__DOT__dut__DOT__u_ctrl__DOT__state = 0U;
                        __Vinline_0__eval_nba___Vinline_0__nba_sequent__TOP__0___Vdly__tb__DOT__dut__DOT__u_ctrl__DOT__timer = 0U;
                        vlSelfRef.tb__DOT__dut__DOT__init_done = 0U;
                        __Vinline_0__eval_nba___Vinline_0__nba_sequent__TOP__0_tb__DOT__ddr_addr = 0U;
                    }
                    vlSelfRef.tb__DOT__dut__DOT__u_ctrl__DOT__timer 
                        = __Vinline_0__eval_nba___Vinline_0__nba_sequent__TOP__0___Vdly__tb__DOT__dut__DOT__u_ctrl__DOT__timer;
                    vlSelfRef.tb__DOT__dut__DOT__u_ctrl__DOT__state 
                        = __Vinline_0__eval_nba___Vinline_0__nba_sequent__TOP__0___Vdly__tb__DOT__dut__DOT__u_ctrl__DOT__state;
                }
            }
        }
        Vtb___024root___trigger_clear__act(vlSelfRef.__VnbaTriggered);
    }
    return (__VnbaExecute);
}

void Vtb___024root___eval(Vtb___024root* vlSelf) {
    VL_DEBUG_IF(VL_DBG_MSGF("+    Vtb___024root___eval\n"); );
    Vtb__Syms* const __restrict vlSymsp VL_ATTR_UNUSED = vlSelf->vlSymsp;
    auto& vlSelfRef = std::ref(*vlSelf).get();
    // Locals
    IData/*31:0*/ __VnbaIterCount;
    // Body
    __VnbaIterCount = 0U;
    do {
        if (VL_UNLIKELY(((0x00002710U < __VnbaIterCount)))) {
#ifdef VL_DEBUG
            Vtb___024root___dump_triggers__act(vlSelfRef.__VnbaTriggered, "nba"s);
#endif
            VL_FATAL_MT("tb.v", 2, "", "DIDNOTCONVERGE: NBA region did not converge after '--converge-limit' of 10000 tries");
        }
        __VnbaIterCount = ((IData)(1U) + __VnbaIterCount);
        vlSelfRef.__VinactIterCount = 0U;
        do {
            if (VL_UNLIKELY(((0x00002710U < vlSelfRef.__VinactIterCount)))) {
                VL_FATAL_MT("tb.v", 2, "", "DIDNOTCONVERGE: Inactive region did not converge after '--converge-limit' of 10000 tries");
            }
            vlSelfRef.__VinactIterCount = ((IData)(1U) 
                                           + vlSelfRef.__VinactIterCount);
            vlSelfRef.__VactIterCount = 0U;
            do {
                if (VL_UNLIKELY(((0x00002710U < vlSelfRef.__VactIterCount)))) {
#ifdef VL_DEBUG
                    Vtb___024root___dump_triggers__act(vlSelfRef.__VactTriggered, "act"s);
#endif
                    VL_FATAL_MT("tb.v", 2, "", "DIDNOTCONVERGE: Active region did not converge after '--converge-limit' of 10000 tries");
                }
                vlSelfRef.__VactIterCount = ((IData)(1U) 
                                             + vlSelfRef.__VactIterCount);
                vlSelfRef.__VactPhaseResult = Vtb___024root___eval_phase__act(vlSelf);
            } while (vlSelfRef.__VactPhaseResult);
            vlSelfRef.__VinactPhaseResult = Vtb___024root___eval_phase__inact(vlSelf);
        } while (vlSelfRef.__VinactPhaseResult);
        vlSelfRef.__VnbaPhaseResult = Vtb___024root___eval_phase__nba(vlSelf);
    } while (vlSelfRef.__VnbaPhaseResult);
}

#ifdef VL_DEBUG
void Vtb___024root___eval_debug_assertions(Vtb___024root* vlSelf) {
    VL_DEBUG_IF(VL_DBG_MSGF("+    Vtb___024root___eval_debug_assertions\n"); );
    Vtb__Syms* const __restrict vlSymsp VL_ATTR_UNUSED = vlSelf->vlSymsp;
    auto& vlSelfRef = std::ref(*vlSelf).get();
}
#endif  // VL_DEBUG
