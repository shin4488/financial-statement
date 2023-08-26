import React from 'react';
import Carousel from 'react-material-ui-carousel';
import { AppCarouselProps } from './props';

export default class AppCarousel extends React.Component<AppCarouselProps> {
  render(): React.ReactNode {
    return <Carousel>{this.props.children}</Carousel>;
  }
}
