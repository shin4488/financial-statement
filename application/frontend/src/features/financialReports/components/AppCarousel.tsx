import React from 'react';
import { useSelector } from 'react-redux';
import Carousel from 'react-material-ui-carousel';
import { RootState } from '@/store/store';

// カルーセルの操作感（6秒の自動切替・スライド・常時ナビ表示）を全カードで統一するラッパー。
// 自動切替のON/OFFだけ画面共通の状態（Redux）を参照する
export default function AppCarousel({
  children,
}: {
  children: React.ReactNode;
}) {
  const isAutoPlay = useSelector(
    (state: RootState) => state.autoPlayStatus.isAutoPlay,
  );
  return (
    <Carousel
      autoPlay={isAutoPlay}
      swipe={false}
      interval={6000}
      stopAutoPlayOnHover
      animation="slide"
      duration={100}
      navButtonsAlwaysVisible
      navButtonsProps={{ style: { opacity: 0.2 } }}
    >
      {children}
    </Carousel>
  );
}
