// rechartsのグラフ内の要素は、クリック・タップでもフォーカスを受ける。
// Chromiumはフォーカスを受けたSVG要素に、キーボード操作でなくても枠を描くため、棒をクリック・タップした後に枠が残る。
// キーボード操作で付く枠（:focus-visible）は残し、ポインタ操作で付く枠だけを消す
export const pointerFocusOutlineHidden = {
  '& .recharts-wrapper :focus:not(:focus-visible)': { outline: 'none' },
};
