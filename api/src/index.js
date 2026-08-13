const express = require("express")
const { Client } = require("@elastic/elasticsearch")

const PORT = Number(process.env.PORT || 3000)
const ELASTICSEARCH_URL = process.env.ELASTICSEARCH_URL || "http://localhost:9200";
const ELASTICSEARCH_USERNAME = process.env.ELASTICSEARCH_USERNAME || "admin";
const ELASTICSEARCH_PASSWORD = process.env.ELASTICSEARCH_PASSWORD || "passw0rd";

const es = new Client({
   node: ELASTICSEARCH_URL,
   auth: {
       username: ELASTICSEARCH_USERNAME,
       password: ELASTICSEARCH_PASSWORD
   }
});
const app = express();

app.use(express.json());

app.get("/health", async (_req, res) => {
    try {
        const health = await es.cluster.health();
        res.json({
            status: "ok",
            elasticsearch: health.status,
        })
    } catch (err) {
        res.status(500).json({status: "unhealthy", error: err.messsage});
    }
});

app.get("/books/search", async (req, res) => {
    const q = String(req.query.q || "").trim()
    const size = Math.min(Number(req.query.size || 10), 50);

    if (!q) {
        return res.status(400).json({error: "Query parameter 'q' is required"});
    }
    try {
        const result = await es.search({
            index: "book",
            size,
            query: {
                multi_match: {
                    query: q,
                    fields: ["name^3", "description"],
                    type: "best_fields",
                    analyzer: "vietnamese_search_analyzer",
                    fuzziness: "AUTO",
                    operator: "and"
                },
            },
            highlight: {
                fields: {
                    name: {},
                    description: {}
                },
            },
        })

        const hits = (result.hits?.hits || [ ]).map((hit) => ({
            id: hit._source?.id ?? hit._id,
            name: hit._source?.name,
            description: hit._source?.description,
            year: hit._source.year,
            score: hit._score,
            hightlight: hit.hightlight
        }));

        res.json({
            q,
            total: result.hits?.total?.value ?? hits.length,
            hits,
        })
    } catch (err) {
        res.status(500).json({ error: err.messsage});
    }
});

app.get("/books", async (req, res) => {
    const size = Math.min(Number(req.query.size || 10), 50);
    try {
        const result = await es.search({
            index: "book",
            size,
            query: {
                match_all: {}
            },
            sort: [
                {
                    id: "asc"
                }
            ]
        })

        res.json({
            total: result.hits?.total?.value ?? 0,
            hits: (result.hits?.hits || []).map((hit) => hit._source),
        })
    } catch (err) {
        res.status(500).json({ error: err.messsage});

    }

});

app.get("/books/:id", async (req, res) => {
   try {
       const result = await es.get({
           index: "book",
           id: req.params.id
       });
       res.json(result._source)
   } catch (err) {
       if (err.meta?.statusCode == 404) {
           return res.status(404).json({error: "Record not found"})
       }
       res.status(500).json({ error: err.messsage});
   }
});

app.listen(PORT, () => {
    console.log(`Search API listening on: ${PORT}`)
    console.log(`Elasticsearch: ${ELASTICSEARCH_URL}`)
})