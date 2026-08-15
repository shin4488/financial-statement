import React from 'react';
import { connect } from 'react-redux';
import Carousel from 'react-material-ui-carousel';
import { AppCarouselProps } from './props';
import { RootState } from '@/store/store';

const mapStateToProps = (state: RootState) => {
  return {
    isAutoPlay: state.autoPlayStatus.isAutoPlay,
  };
};
type AppCarouselWithStoreProps = AppCarouselProps &
  ReturnType<typeof mapStateToProps>;

class AppCarousel extends React.Component<AppCarouselWithStoreProps> {
  render(): React.ReactNode {
    return (
      <Carousel
        autoPlay={this.props.isAutoPlay}
        swipe={false}
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

export default connect(mapStateToProps)(AppCarousel);
