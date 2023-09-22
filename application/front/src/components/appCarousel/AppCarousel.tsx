import React from 'react';
import Carousel from 'react-material-ui-carousel';
import { AppCarouselProps } from './props';
import { AppCarouselState } from './state';

export default class AppCarousel extends React.Component<
  AppCarouselProps,
  AppCarouselState
> {
  state: Readonly<AppCarouselState> = {
    isAutoPlay: true,
  };

  render(): React.ReactNode {
    return (
      <Carousel
        next={() => {
          // noop
        }}
        prev={() => {
          // noop
        }}
        onChange={(now, previous) => {
          if (now === undefined || previous === undefined) {
            return;
          }

          // 一番最後の表示から一番最初の表示に変わったら（auto playを1周など）auto playを止める
          // とりあえず全部のデータを見てもらいたいが、ずっとauto playなのも目障りと思われるため
          // ユーザー自身で前へボタンを押したときもauto playを止める（前へ戻るということは、そのデータが気になっていると思われるため）
          if (now < previous) {
            this.setState({ isAutoPlay: false });
          }
        }}
        autoPlay={this.state.isAutoPlay}
        interval={6000}
        stopAutoPlayOnHover
        animation="slide"
        duration={100}
        navButtonsAlwaysVisible
        navButtonsProps={{ style: { opacity: 0.2 } }}
      >
        {this.props.children}
      </Carousel>
    );
  }
}
