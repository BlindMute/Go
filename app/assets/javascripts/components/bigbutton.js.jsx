class BigButton extends React.Component {
	constructor(props) {
		super(props)
		this.state = {
			selected: false
		}
	}

	render() {
		let classes = 'game-creation-button'
		if (this.props.selected) classes += ' selected';
		if (this.props.disabled) classes += ' disabled';

		return (
			<div onClick={() => this.props.onClick()}
				 className={classes}>
				{this.props.text}
			</div>
		);

	}
}