import * as React from "react";
import { DisplayType, DisplayTypeContext } from "../context/DisplayType";
import DetailCard from "./Card/DetailCard";
import SimpleCard from "./Card/SimpleCard";
import ThumbCard from "./Card/ThumbCard";
import BookData, { BookInfo } from "./BookData";
import Portal from "../../Portal";
import { SearchQuery } from "../header/Search";

export const DataType = {
	UnreadList: "list/unread",
	ToBuyList: "list/to-buy",
	ToBuyUnpublishedList: "list/to-buy/unpublished",
	HoldList: "list/hold",
	SearchList: "search",
} as const;
export type DataType = typeof DataType[keyof typeof DataType];

type Props = {
	dataType: DataType;
	searchQuery?: SearchQuery | null;
};

export default function BookList(props: Props = {
	dataType: DataType.ToBuyList,
	searchQuery: null,
}) {
	const [books, setBooks] = React.useState<BookInfo[] | null>(null);
	const [book, setBook] = React.useState<BookInfo | null>(null);
	const [update, setUpdate] = React.useState(0);
	const displayType = React.useContext(DisplayTypeContext);

	React.useEffect(() => {
		let api = props.dataType;
		if (props.dataType == DataType.SearchList) {
			if (!props.searchQuery) {
				setBooks([]);
				return;
			}
			api += `?${Object.entries(props.searchQuery).map(v => `${v[0]}=${encodeURIComponent(v[1])}`).join("&")}`;
		}
		setBooks(null);
		GET(api).then(r => r.json())
			.then(json => {
				if (json.error)
					throw json.error;
				setBooks(json)
			})
			.catch(e => {
				console.error(e);
				setBooks([])
			});
	}, [update, props.dataType, props.searchQuery]);

	if (books == null)
		return <div className="notify-board"><span className="notify-board-message">Loading ...</span></div>;
	if (books.length == 0)
		return <div className="notify-board"><span className="notify-board-message">書籍情報が見つかりません</span></div>;

	return (<>
		{(() => {
			if (displayType.type == DisplayType.Thumb)
				return <div className="book-list book-list-thumb">{books.map(book => <ThumbCard key={book.isbn} book={book} setBook={setBook} />)}</div>;
			else if (displayType.type == DisplayType.Simple)
				return <div className="book-list">{books.map(book => <SimpleCard key={book.isbn} book={book} setBook={setBook} />)}</div>;
			return <div className="book-list">{books.map(book => <DetailCard key={book.isbn} book={book} setBook={setBook} />)}</div>;
		})()}
		<Portal targetID="modal">
			<BookData dataType={props.dataType} book={book} setBook={setBook} handleUpdate={setUpdate} />
		</Portal>
	</>);
}