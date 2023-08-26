import React from 'react';
import Carousel from 'react-material-ui-carousel';
import { AppCarouselProps } from './props';

export default class AppCarousel extends React.Component<AppCarouselProps> {
  render(): React.ReactNode {
    return (
      <Carousel
        next={() => {
          /* noop */
        }}
        prev={() => {
          /* noop */
        }}
        interval={6000}
        stopAutoPlayOnHover
        animation="slide"
        duration={100}
        navButtonsAlwaysVisible
        navButtonsProps={{ style: { opacity: 0.3 } }}
      >
        {this.props.children}
      </Carousel>
    );
  }
}
