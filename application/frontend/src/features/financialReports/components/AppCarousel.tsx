import React, { useRef } from 'react';
import { useSelector } from 'react-redux';
import Carousel from 'react-material-ui-carousel';
import { RootState } from '@/store/store';
import { trackEvent, ProductParams } from '@/plugins/firebase/analytics';

// ナビボタンはカルーセル下端の帯に置かれる。インジケータ行を同じ高さにしないと、ボタンが行からスライド側へはみ出し、幅の狭い画面ではチャートの下端に重なる
const navRowHeight = 40;

// カルーセルの操作感（6秒の自動切替・スライド・常時ナビ表示）を全カードで統一するラッパー。
// 自動切替のON/OFFだけ画面共通の状態（Redux）を参照する
export default function AppCarousel({
  children,
}: {
  children: React.ReactNode;
}) {
  const manualNavigation = useRef(false);
  const buttonProps = {
    style: { opacity: 0.2 },
    onClickCapture: () => {
      manualNavigation.current = true;
    },
  };
  const indicatorProps = {
    className: '',
    onClickCapture: buttonProps.onClickCapture,
  };
  const isAutoPlay = useSelector(
    (state: RootState) => state.autoPlayStatus.isAutoPlay,
  );
  return (
    <Carousel
      onChange={(now, previous) => {
        if (manualNavigation.current && now !== previous) {
          const chartTypes: ProductParams['chart_type'][] = [
            'bs',
            'pl',
            'cf',
            'fcf',
            'indicators',
          ];
          trackEvent('analysis_interaction', {
            interaction_type: 'chart_navigation',
            chart_type: chartTypes[now ?? 0],
          });
        }
        manualNavigation.current = false;
      }}
      indicatorContainerProps={{
        style: {
          marginTop: 0,
          height: navRowHeight,
          display: 'flex',
          alignItems: 'center',
          justifyContent: 'center',
        },
      }}
      indicatorIconButtonProps={indicatorProps}
      autoPlay={isAutoPlay}
      swipe={false}
      interval={6000}
      stopAutoPlayOnHover
      animation="slide"
      duration={100}
      navButtonsAlwaysVisible
      navButtonsWrapperProps={{
        style: { top: 'auto', bottom: 0, height: navRowHeight },
      }}
      navButtonsProps={buttonProps}
    >
      {children}
    </Carousel>
  );
}
